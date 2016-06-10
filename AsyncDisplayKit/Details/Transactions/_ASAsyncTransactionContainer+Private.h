//
//  _ASAsyncTransactionContainer+Private.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>


@interface CALayer (ASAsyncTransactionContainerTransactions)
@property (nonatomic, strong, setter=asyncdisplaykit_setAsyncLayerTransactions:) NSHashTable *asyncdisplaykit_asyncLayerTransactions;
@property (nonatomic, strong, setter=asyncdisplaykit_setCurrentAsyncLayerTransaction:) _ASAsyncTransaction *asyncdisplaykit_currentAsyncLayerTransaction;

- (void)asyncdisplaykit_asyncTransactionContainerWillBeginTransaction:(_ASAsyncTransaction *)transaction;
- (void)asyncdisplaykit_asyncTransactionContainerDidCompleteTransaction:(_ASAsyncTransaction *)transaction;
@end
