//
//  _ASAsyncTransactionContainer.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once 

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class _ASAsyncTransaction;

typedef NS_ENUM(NSUInteger, ASAsyncTransactionContainerState) {
  /**
   The async container has no outstanding transactions.
   Whatever it is displaying is up-to-date.
   */
  ASAsyncTransactionContainerStateNoTransactions = 0,
  /**
   The async container has one or more outstanding async transactions.
   Its contents may be out of date or showing a placeholder, depending on the configuration of the contained ASDisplayLayers.
   */
  ASAsyncTransactionContainerStatePendingTransactions,
};

@protocol ASAsyncTransactionContainer

/**
 @summary If YES, the receiver is marked as a container for async transactions, grouping all of the transactions
 in the container hierarchy below the receiver together in a single ASAsyncTransaction.

 @default NO
 */
@property (nonatomic, assign, getter=asyncdisplaykit_isAsyncTransactionContainer, setter=asyncdisplaykit_setAsyncTransactionContainer:) BOOL asyncdisplaykit_asyncTransactionContainer;

/**
 @summary The current state of the receiver; indicates if it is currently performing asynchronous operations or if all operations have finished/canceled.
 */
@property (nonatomic, readonly, assign) ASAsyncTransactionContainerState asyncdisplaykit_asyncTransactionContainerState;

/**
 @summary Cancels all async transactions on the receiver.
 */
- (void)asyncdisplaykit_cancelAsyncTransactions;

@property (nonatomic, strong, nullable, setter=asyncdisplaykit_setCurrentAsyncTransaction:) _ASAsyncTransaction *asyncdisplaykit_currentAsyncTransaction;

@end

@interface CALayer (ASAsyncTransactionContainer) <ASAsyncTransactionContainer>
/**
 @summary Returns the current async transaction for this layer. A new transaction is created if one
 did not already exist. This method will always return an open, uncommitted transaction.
 @desc asyncdisplaykit_isAsyncTransactionContainer does not need to be YES for this to return a transaction.
 */
@property (nonatomic, readonly, strong, nullable) _ASAsyncTransaction *asyncdisplaykit_asyncTransaction;

/**
 @summary Goes up the superlayer chain until it finds the first layer with asyncdisplaykit_isAsyncTransactionContainer=YES (including the receiver) and returns it.
 Returns nil if no parent container is found.
 */
@property (nonatomic, readonly, strong, nullable) CALayer *asyncdisplaykit_parentTransactionContainer;
@end

@interface UIView (ASAsyncTransactionContainer) <ASAsyncTransactionContainer>
@end

NS_ASSUME_NONNULL_END
