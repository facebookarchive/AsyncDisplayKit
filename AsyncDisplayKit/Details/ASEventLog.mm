//
//  ASEventLog.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 4/11/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASEventLog.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASTraceEvent.h>
#import <AsyncDisplayKit/ASObjectDescriptionHelpers.h>

@implementation ASEventLog {
  ASDN::RecursiveMutex __instanceLock__;

  // The index of the most recent log entry. -1 until first entry.
  NSInteger _eventLogHead;

  // A description of the object we're logging for. This is immutable.
  NSString *_objectDescription;
}

/**
 * Even just when debugging, all these events can take up considerable memory.
 * Store them in a shared NSCache to limit the total consumption.
 */
+ (NSCache<ASEventLog *, NSMutableArray<ASTraceEvent *> *> *)contentsCache
{
  static NSCache *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [[NSCache alloc] init];
  });
  return cache;
}

- (instancetype)initWithObject:(id)anObject
{
  if ((self = [super init])) {
    _objectDescription = ASObjectDescriptionMakeTiny(anObject);
    _eventLogHead = -1;
  }
  return self;
}

- (instancetype)init
{
  // This method is marked unavailable so the compiler won't let them call it.
  ASDisplayNodeFailAssert(@"Failed to call initWithObject:");
  return nil;
}

- (void)logEventWithBacktrace:(NSArray<NSString *> *)backtrace format:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  ASTraceEvent *event = [[ASTraceEvent alloc] initWithBacktrace:backtrace
                                                         format:format
                                                      arguments:args];
  va_end(args);

  ASDN::MutexLocker l(__instanceLock__);
  NSCache *cache = [ASEventLog contentsCache];
  NSMutableArray<ASTraceEvent *> *events = [cache objectForKey:self];
  if (events == nil) {
    events = [NSMutableArray arrayWithObject:event];
    [cache setObject:events forKey:self];
    _eventLogHead = 0;
    return;
  }

  // Increment the head index.
  _eventLogHead = (_eventLogHead + 1) % ASEVENTLOG_CAPACITY;
  if (_eventLogHead < events.count) {
    [events replaceObjectAtIndex:_eventLogHead withObject:event];
  } else {
    [events insertObject:event atIndex:_eventLogHead];
  }
}

- (NSArray<ASTraceEvent *> *)events
{
  NSMutableArray<ASTraceEvent *> *events = [[ASEventLog contentsCache] objectForKey:self];
  if (events == nil) {
    return nil;
  }

  ASDN::MutexLocker l(__instanceLock__);
  NSUInteger tail = (_eventLogHead + 1);
  NSUInteger count = events.count;
  
  NSMutableArray<ASTraceEvent *> *result = [NSMutableArray array];
  
  // Start from `tail` and go through array, wrapping around when we exceed end index.
  for (NSUInteger actualIndex = 0; actualIndex < ASEVENTLOG_CAPACITY; actualIndex++) {
    NSInteger ringIndex = (tail + actualIndex) % ASEVENTLOG_CAPACITY;
    if (ringIndex < count) {
      [result addObject:events[ringIndex]];
    }
  }
  return result;
}

- (NSString *)description
{
  /**
   * This description intentionally doesn't follow the standard description format.
   * Since this is a log, it's important for the description to look a certain way, and
   * the formal description style doesn't allow for newlines and has a ton of punctuation.
   */
  NSArray *events = [self events];
  if (events == nil) {
    return [NSString stringWithFormat:@"Event log for %@ was purged to conserve memory.", _objectDescription];
  } else {
    return [NSString stringWithFormat:@"Event log for %@. Events: %@", _objectDescription, events];
  }
}

@end
