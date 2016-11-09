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

#import "ASEventLog.h"
#import "ASThread.h"
#import "ASTraceEvent.h"

@interface ASEventLog ()
{
  ASDN::RecursiveMutex __instanceLock__;
  // The index of the most recent log entry. -1 until first entry.
  NSInteger _eventLogHead;
  // The most recent trace events. Max count is ASEVENTLOG_CAPACITY.
  NSMutableArray<ASTraceEvent *> *_eventLog;
}
@end

@implementation ASEventLog

- (instancetype)init
{
  if ((self = [super init])) {
    _eventLogHead = -1;
  }
  return self;
}

- (void)logEventWithBacktrace:(NSArray<NSString *> *)backtrace format:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  ASTraceEvent *event = [[ASTraceEvent alloc] initWithObject:self
                                                   backtrace:backtrace
                                                      format:format
                                                   arguments:args];
  va_end(args);
  
  ASDN::MutexLocker l(__instanceLock__);
  // Create the array if needed.
  if (_eventLog == nil) {
    _eventLog = [NSMutableArray arrayWithCapacity:ASEVENTLOG_CAPACITY];
  }
  
  // Increment the head index.
  _eventLogHead = (_eventLogHead + 1) % ASEVENTLOG_CAPACITY;
  if (_eventLogHead < _eventLog.count) {
    [_eventLog replaceObjectAtIndex:_eventLogHead withObject:event];
  } else {
    [_eventLog insertObject:event atIndex:_eventLogHead];
  }
}

- (NSArray<ASTraceEvent *> *)eventLog
{
  ASDN::MutexLocker l(__instanceLock__);
  NSUInteger tail = (_eventLogHead + 1);
  NSUInteger count = _eventLog.count;
  
  NSMutableArray<ASTraceEvent *> *result = [NSMutableArray array];
  
  // Start from `tail` and go through array, wrapping around when we exceed end index.
  for (NSUInteger actualIndex = 0; actualIndex < ASEVENTLOG_CAPACITY; actualIndex++) {
    NSInteger ringIndex = (tail + actualIndex) % ASEVENTLOG_CAPACITY;
    if (ringIndex < count) {
      [result addObject:_eventLog[ringIndex]];
    }
  }
  return result;
}

@end
