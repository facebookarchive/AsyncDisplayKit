//
//  ASEventLog.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 4/11/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#ifndef ASEVENTLOG_CAPACITY
#define ASEVENTLOG_CAPACITY 5
#endif

#ifndef ASEVENTLOG_ENABLE
#define ASEVENTLOG_ENABLE DEBUG
#endif

NS_ASSUME_NONNULL_BEGIN

@interface ASEventLog : NSObject

/**
 * Create a new event log.
 *
 * @param anObject The object whose events we are logging. This object is not retained.
 */
- (instancetype)initWithObject:(id)anObject;

- (void)logEventWithBacktrace:(nullable NSArray<NSString *> *)backtrace format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
