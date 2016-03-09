//
//  ASRunLoopQueue.m
//  AsyncDisplayKit
//
//  Created by Rahul Malik on 3/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASRunLoopQueue.h"
#import "ASThread.h"

#import <deque>

@interface ASRunLoopQueue () {
  CFRunLoopRef _runLoop;
  CFRunLoopObserverRef _runLoopObserver;
  std::deque<id> _internalQueue;
  ASDN::RecursiveMutex _internalQueueLock;
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
  }
  return self;
}

- (void)dealloc
{
  if (CFRunLoopObserverIsValid(_runLoopObserver)) {
    CFRunLoopObserverInvalidate(_runLoopObserver);
  }
  CFRelease(_runLoopObserver);
  _runLoopObserver = nil;
}

- (void)processQueue
{
  std::deque<id> itemsToProcess = std::deque<id>();
  BOOL isQueueDrained = NO;
  CFAbsoluteTime timestamp = 0;
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
      timestamp = CFAbsoluteTimeGetCurrent();
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
  }
}

@end
