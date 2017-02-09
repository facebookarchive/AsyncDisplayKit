//
//  _ASAsyncTransactionGroup.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class _ASAsyncTransaction;
@protocol ASAsyncTransactionContainer;

/// A group of transaction containers, for which the current transactions are committed together at the end of the next runloop tick.
@interface _ASAsyncTransactionGroup : NSObject
/// The main transaction group is scheduled to commit on every tick of the main runloop.
+ (_ASAsyncTransactionGroup *)mainTransactionGroup;
+ (void)commit;

/// Add a transaction container to be committed.
/// @see ASAsyncTransactionContainer
- (void)addTransactionContainer:(id<ASAsyncTransactionContainer>)container;
@end

NS_ASSUME_NONNULL_END
