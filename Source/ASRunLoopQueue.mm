//
//  ASRunLoopQueue.mm
//  AsyncDisplayKit
//
//  Created by Rahul Malik on 3/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASLog.h>

#import <cstdlib>
#import <deque>
#import <vector>

#define ASRunLoopQueueLoggingEnabled 0
#define ASRunLoopQueueVerboseLoggingEnabled 0

static void runLoopSourceCallback(void *info) {
  // No-op
#if ASRunLoopQueueVerboseLoggingEnabled
  NSLog(@"<%@> - Called runLoopSourceCallback", info);
#endif
}

#pragma mark - ASDeallocQueue

@implementation ASDeallocQueue {
  NSThread *_thread;
  NSCondition *_condition;
  std::deque<id> _queue;
  ASDN::RecursiveMutex _queueLock;
}

+ (instancetype)sharedDeallocationQueue
{
  static ASDeallocQueue *deallocQueue = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    deallocQueue = [[ASDeallocQueue alloc] init];
  });
  return deallocQueue;
}

- (void)releaseObjectInBackground:(id)object
{
  // Disable background deallocation on iOS 8 and below to avoid crashes related to UIAXDelegateClearer (#2767).
  if (!AS_AT_LEAST_IOS9) {
    return;
  }

  _queueLock.lock();
  _queue.push_back(object);
  _queueLock.unlock();
}

- (void)threadMain
{
  @autoreleasepool {
    __unsafe_unretained __typeof__(self) weakSelf = self;
    // 100ms timer.  No resources are wasted in between, as the thread sleeps, and each check is fast.
    // This time is fast enough for most use cases without excessive churn.
    CFRunLoopTimerRef timer = CFRunLoopTimerCreateWithHandler(NULL, -1, 0.1, 0, 0, ^(CFRunLoopTimerRef timer) {
      weakSelf->_queueLock.lock();
      if (weakSelf->_queue.size() == 0) {
        weakSelf->_queueLock.unlock();
        return;
      }
      // The scope below is entered while already locked. @autorelease is crucial here; see PR 2890.
      @autoreleasepool {
#if ASRunLoopQueueLoggingEnabled
        NSLog(@"ASDeallocQueue Processing: %lu objects destroyed", weakSelf->_queue.size());
#endif
        // Sometimes we release 10,000 objects at a time.  Don't hold the lock while releasing.
        std::deque<id> currentQueue = weakSelf->_queue;
        weakSelf->_queue = std::deque<id>();
        weakSelf->_queueLock.unlock();
        currentQueue.clear();
      }
    });
    
    CFRunLoopRef runloop = CFRunLoopGetCurrent();
    CFRunLoopAddTimer(runloop, timer, kCFRunLoopCommonModes);
    
    [_condition lock];
    [_condition signal];
    // At this moment, -init is signalled that the thread is guaranteed to be finished starting.
    [_condition unlock];
    
    // Keep processing events until the runloop is stopped.
    CFRunLoopRun();
    
    CFRunLoopTimerInvalidate(timer);
    CFRunLoopRemoveTimer(runloop, timer, kCFRunLoopCommonModes);
    CFRelease(timer);
    
    [_condition lock];
    [_condition signal];
    // At this moment, -stop is signalled that the thread is guaranteed to be finished exiting.
    [_condition unlock];
  }
}

- (instancetype)init
{
  if ((self = [super init])) {
    _condition = [[NSCondition alloc] init];
    
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(threadMain) object:nil];
    _thread.name = @"ASDeallocQueue";
    
    // Use condition to ensure NSThread has finished starting.
    [_condition lock];
    [_thread start];
    [_condition wait];
    [_condition unlock];
  }
  return self;
}

- (void)stop
{
  if (!_thread) {
    return;
  }
  
  [_condition lock];
  [self performSelector:@selector(_stop) onThread:_thread withObject:nil waitUntilDone:NO];
  [_condition wait];
  // At this moment, the thread is guaranteed to be finished running.
  [_condition unlock];
  _thread = nil;
}

- (void)_stop
{
  CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)dealloc
{
  [self stop];
}

@end

#pragma mark - ASRunLoopQueue

@interface ASRunLoopQueue () {
  CFRunLoopRef _runLoop;
  CFRunLoopSourceRef _runLoopSource;
  CFRunLoopObserverRef _runLoopObserver;
  NSPointerArray *_internalQueue; // Use NSPointerArray so we can decide __strong or __weak per-instance.
  ASDN::RecursiveMutex _internalQueueLock;
  
#if ASRunLoopQueueLoggingEnabled
  NSTimer *_runloopQueueLoggingTimer;
#endif
}

@property (nonatomic, copy) void (^queueConsumer)(id dequeuedItem, BOOL isQueueDrained);

@end

@implementation ASRunLoopQueue

- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop retainObjects:(BOOL)retainsObjects handler:(void (^)(id _Nullable, BOOL))handlerBlock
{
  if (self = [super init]) {
    _runLoop = runloop;
    NSPointerFunctionsOptions options = retainsObjects ? NSPointerFunctionsStrongMemory : NSPointerFunctionsWeakMemory;
    _internalQueue = [[NSPointerArray alloc] initWithOptions:options];
    _queueConsumer = handlerBlock;
    _batchSize = 1;
    _ensureExclusiveMembership = YES;
    
    // Self is guaranteed to outlive the observer.  Without the high cost of a weak pointer,
    // __unsafe_unretained allows us to avoid flagging the memory cycle detector.
    __unsafe_unretained __typeof__(self) weakSelf = self;
    void (^handlerBlock) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      [weakSelf processQueue];
    };
    _runLoopObserver = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, handlerBlock);
    CFRunLoopAddObserver(_runLoop, _runLoopObserver,  kCFRunLoopCommonModes);
    
    // It is not guaranteed that the runloop will turn if it has no scheduled work, and this causes processing of
    // the queue to stop. Attaching a custom loop source to the run loop and signal it if new work needs to be done
    CFRunLoopSourceContext sourceContext = {};
    sourceContext.perform = runLoopSourceCallback;
#if ASRunLoopQueueLoggingEnabled
    sourceContext.info = (__bridge void *)self;
#endif
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, &sourceContext);
    CFRunLoopAddSource(runloop, _runLoopSource, kCFRunLoopCommonModes);

#if ASRunLoopQueueLoggingEnabled
    _runloopQueueLoggingTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(checkRunLoop) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_runloopQueueLoggingTimer forMode:NSRunLoopCommonModes];
#endif
  }
  return self;
}

- (void)dealloc
{
  if (CFRunLoopContainsSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes)) {
    CFRunLoopRemoveSource(_runLoop, _runLoopSource, kCFRunLoopCommonModes);
  }
  CFRelease(_runLoopSource);
  _runLoopSource = nil;
  
  if (CFRunLoopObserverIsValid(_runLoopObserver)) {
    CFRunLoopObserverInvalidate(_runLoopObserver);
  }
  CFRelease(_runLoopObserver);
  _runLoopObserver = nil;
}

#if ASRunLoopQueueLoggingEnabled
- (void)checkRunLoop
{
    NSLog(@"<%@> - Jobs: %ld", self, _internalQueue.size());
}
#endif

- (void)processQueue
{
  BOOL hasExecutionBlock = (_queueConsumer != nil);

  // If we have an execution block, this vector will be populated, otherwise remains empty.
  // This is to avoid needlessly retaining/releasing the objects if we don't have a block.
  std::vector<id> itemsToProcess;

  BOOL isQueueDrained = NO;
  {
    ASDN::MutexLocker l(_internalQueueLock);

    // Early-exit if the queue is empty.
    NSInteger internalQueueCount = _internalQueue.count;
    if (internalQueueCount == 0) {
      return;
    }
    
    ASProfilingSignpostStart(0, self);

    // Snatch the next batch of items.
    NSInteger maxCountToProcess = MIN(internalQueueCount, self.batchSize);

    /**
     * For each item in the next batch, if it's non-nil then NULL it out
     * and if we have an execution block then add it in.
     * This could be written a bunch of different ways but
     * this particular one nicely balances readability, safety, and efficiency.
     */
    NSInteger foundItemCount = 0;
    for (NSInteger i = 0; i < internalQueueCount && foundItemCount < maxCountToProcess; i++) {
      /**
       * It is safe to use unsafe_unretained here. If the queue is weak, the
       * object will be added to the autorelease pool. If the queue is strong,
       * it will retain the object until we transfer it (retain it) in itemsToProcess.
       */
      __unsafe_unretained id ptr = (__bridge id)[_internalQueue pointerAtIndex:i];
      if (ptr != nil) {
        foundItemCount++;
        if (hasExecutionBlock) {
          itemsToProcess.push_back(ptr);
        }
        [_internalQueue replacePointerAtIndex:i withPointer:NULL];
      }
    }

    [_internalQueue compact];
    if (_internalQueue.count == 0) {
      isQueueDrained = YES;
    }
  }

  // itemsToProcess will be empty if _queueConsumer == nil so no need to check again.
  if (itemsToProcess.empty() == false) {
#if ASRunLoopQueueLoggingEnabled
    NSLog(@"<%@> - Starting processing of: %ld", self, itemsToProcess.size());
#endif
    auto itemsEnd = itemsToProcess.cend();
    for (auto iterator = itemsToProcess.begin(); iterator < itemsEnd; iterator++) {
      _queueConsumer(*iterator, isQueueDrained && iterator == itemsEnd - 1);
#if ASRunLoopQueueLoggingEnabled
      NSLog(@"<%@> - Finished processing 1 item", self);
#endif
    }
  }

  // If the queue is not fully drained yet force another run loop to process next batch of items
  if (!isQueueDrained) {
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
  
  ASProfilingSignpostEnd(0, self);
}

- (void)enqueue:(id)object
{
  if (!object) {
    return;
  }
  
  ASDN::MutexLocker l(_internalQueueLock);

  // Check if the object exists.
  BOOL foundObject = NO;
    
  if (_ensureExclusiveMembership) {
    for (id currentObject in _internalQueue) {
      if (currentObject == object) {
        foundObject = YES;
        break;
      }
    }
  }

  if (!foundObject) {
    [_internalQueue addPointer:(__bridge void *)object];
    
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
}

@end
