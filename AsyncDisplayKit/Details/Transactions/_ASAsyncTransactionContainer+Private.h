//
//  _ASAsyncTransactionContainer+Private.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@class _ASAsyncTransaction;

@interface CALayer (ASAsyncTransactionContainerTransactions)
@property (nonatomic, strong, nullable, setter=asyncdisplaykit_setAsyncLayerTransactions:) NSHashTable<_ASAsyncTransaction *> *asyncdisplaykit_asyncLayerTransactions;

- (void)asyncdisplaykit_asyncTransactionContainerWillBeginTransaction:(_ASAsyncTransaction *)transaction;
- (void)asyncdisplaykit_asyncTransactionContainerDidCompleteTransaction:(_ASAsyncTransaction *)transaction;
@end

NS_ASSUME_NONNULL_END
