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

#import <AsyncDisplayKit/ASRunLoopQueue.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASLog.h>

#import <cstdlib>
#import <deque>
#import <vector>

#define ASRunLoopQueueLoggingEnabled 0

static void runLoopSourceCallback(void *info) {
  // No-op
#if ASRunLoopQueueLoggingEnabled
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
      @autoreleasepool {
#if ASRunLoopQueueLoggingEnabled
        NSLog(@"ASDeallocQueue Processing: %d objects destroyed", weakSelf->_queue.size());
#endif
        weakSelf->_queueLock.lock();
        std::deque<id> currentQueue = weakSelf->_queue;
        if (currentQueue.size() == 0) {
          weakSelf->_queueLock.unlock();
          return;
        }
        // Sometimes we release 10,000 objects at a time.  Don't hold the lock while releasing.
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
  std::deque<id> _internalQueue;
  ASDN::RecursiveMutex _internalQueueLock;
  
#if ASRunLoopQueueLoggingEnabled
  NSTimer *_runloopQueueLoggingTimer;
#endif
}

@property (nonatomic, copy) void (^queueConsumer)(id dequeuedItem, BOOL isQueueDrained);

@end

@implementation ASRunLoopQueue

- (instancetype)initWithRunLoop:(CFRunLoopRef)runloop andHandler:(void(^)(id dequeuedItem, BOOL isQueueDrained))handlerBlock
{
  if (self = [super init]) {
    _runLoop = runloop;
    _internalQueue = std::deque<id>();
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
    CFRunLoopSourceContext *runLoopSourceContext = (CFRunLoopSourceContext *)calloc(1, sizeof(CFRunLoopSourceContext));
    if (runLoopSourceContext) {
      runLoopSourceContext->perform = runLoopSourceCallback;
#if ASRunLoopQueueLoggingEnabled
      runLoopSourceContext->info = (__bridge void *)self;
#endif
      _runLoopSource = CFRunLoopSourceCreate(NULL, 0, runLoopSourceContext);
      CFRunLoopAddSource(runloop, _runLoopSource, kCFRunLoopCommonModes);
      free(runLoopSourceContext);
    }

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
    if (_internalQueue.empty()) {
      return;
    }
    
    ASProfilingSignpostStart(0, self);

    // Snatch the next batch of items.
    auto firstItemToProcess = _internalQueue.cbegin();
    auto lastItemToProcess = MIN(_internalQueue.cend(), firstItemToProcess + self.batchSize);

    if (hasExecutionBlock) {
      itemsToProcess = std::vector<id>(firstItemToProcess, lastItemToProcess);
    }
    _internalQueue.erase(firstItemToProcess, lastItemToProcess);

    if (_internalQueue.empty()) {
      isQueueDrained = YES;
    }
  }

  // itemsToProcess will be empty if _queueConsumer == nil so no need to check again.
  auto itemsEnd = itemsToProcess.cend();
  for (auto iterator = itemsToProcess.begin(); iterator < itemsEnd; iterator++) {
    _queueConsumer(*iterator, isQueueDrained && iterator == itemsEnd - 1);
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
    for (id currentObject : _internalQueue) {
      if (currentObject == object) {
        foundObject = YES;
        break;
      }
    }
  }

  if (!foundObject) {
    _internalQueue.push_back(object);
    
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
}

@end
