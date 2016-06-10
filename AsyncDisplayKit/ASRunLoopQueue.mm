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

#import "ASRunLoopQueue.h"
#import "ASThread.h"

#import <cstdlib>
#import <deque>

#define ASRunLoopQueueLoggingEnabled 0

static void runLoopSourceCallback(void *info) {
  // No-op
#if ASRunLoopQueueLoggingEnabled
  NSLog(@"<%@> - Called runLoopSourceCallback", info);
#endif
}

@interface ASRunLoopQueue () {
  CFRunLoopRef _runLoop;
  CFRunLoopObserverRef _runLoopObserver;
  CFRunLoopSourceRef _runLoopSource;
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
    _queueConsumer = [handlerBlock copy];
    _batchSize = 1;
    void (^handlerBlock) (CFRunLoopObserverRef observer, CFRunLoopActivity activity) = ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
      [self processQueue];
    };
    _runLoopObserver = CFRunLoopObserverCreateWithHandler(NULL, kCFRunLoopBeforeWaiting, true, 0, handlerBlock);
    CFRunLoopAddObserver(_runLoop, _runLoopObserver,  kCFRunLoopCommonModes);
    
    // It is not guaranteed that the runloop will turn if it has no scheduled work, and this causes processing of
    // the queue to stop. Attaching a custom loop source to the run loop and signal it if new work needs to be done
    CFRunLoopSourceContext *runLoopSourceContext = (CFRunLoopSourceContext *)calloc(1, sizeof(CFRunLoopSourceContext));
    runLoopSourceContext->perform = runLoopSourceCallback;
#if ASRunLoopQueueLoggingEnabled
    runLoopSourceContext->info = (__bridge void *)self;
#endif
    _runLoopSource = CFRunLoopSourceCreate(NULL, 0, runLoopSourceContext);
    CFRunLoopAddSource(runloop, _runLoopSource, kCFRunLoopCommonModes);
    free(runLoopSourceContext);

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
  std::deque<id> itemsToProcess = std::deque<id>();
  BOOL isQueueDrained = NO;
  {
    ASDN::MutexLocker l(_internalQueueLock);

    // Early-exit if the queue is empty.
    if (_internalQueue.empty()) {
      return;
    }

    // Snatch the next batch of items.
    NSUInteger totalNodeCount = _internalQueue.size();
    for (int i = 0; i < MIN(self.batchSize, totalNodeCount); i++) {
      id node = _internalQueue[0];
      itemsToProcess.push_back(node);
      _internalQueue.pop_front();
    }

    if (_internalQueue.empty()) {
      isQueueDrained = YES;
    }
  }

  unsigned long numberOfItems = itemsToProcess.size();
  for (int i = 0; i < numberOfItems; i++) {
    if (isQueueDrained && i == numberOfItems - 1) {
      self.queueConsumer(itemsToProcess[i], YES);
    } else {
      self.queueConsumer(itemsToProcess[i], isQueueDrained);
    }
  }

  // If the queue is not fully drained yet force another run loop to process next batch of items
  if (!isQueueDrained) {
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
   }
}

- (void)enqueue:(id)object
{
  if (!object) {
    return;
  }
  
  ASDN::MutexLocker l(_internalQueueLock);

  // Check if the object exists.
  BOOL foundObject = NO;
  for (id currentObject : _internalQueue) {
    if (currentObject == object) {
      foundObject = YES;
      break;
    }
  }

  if (!foundObject) {
    _internalQueue.push_back(object);
    
    CFRunLoopSourceSignal(_runLoopSource);
    CFRunLoopWakeUp(_runLoop);
  }
}

@end
