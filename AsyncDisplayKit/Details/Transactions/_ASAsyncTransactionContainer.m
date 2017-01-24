//
//  _ASAsyncTransactionContainer.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer+Private.h>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASAsyncTransactionGroup.h>
#import <objc/runtime.h>

static const char *ASDisplayNodeAssociatedTransactionsKey = "ASAssociatedTransactions";
static const char *ASDisplayNodeAssociatedCurrentTransactionKey = "ASAssociatedCurrentTransaction";

@implementation CALayer (ASAsyncTransactionContainerTransactions)

- (NSHashTable *)asyncdisplaykit_asyncLayerTransactions
{
  return objc_getAssociatedObject(self, ASDisplayNodeAssociatedTransactionsKey);
}

- (void)asyncdisplaykit_setAsyncLayerTransactions:(NSHashTable *)transactions
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedTransactionsKey, transactions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// No-ops in the base class. Mostly exposed for testing.
- (void)asyncdisplaykit_asyncTransactionContainerWillBeginTransaction:(_ASAsyncTransaction *)transaction {}
- (void)asyncdisplaykit_asyncTransactionContainerDidCompleteTransaction:(_ASAsyncTransaction *)transaction {}
@end

static const char *ASAsyncTransactionIsContainerKey = "ASTransactionIsContainer";

@implementation CALayer (ASAsyncTransactionContainer)

- (_ASAsyncTransaction *)asyncdisplaykit_currentAsyncTransaction
{
  return objc_getAssociatedObject(self, ASDisplayNodeAssociatedCurrentTransactionKey);
}

- (void)asyncdisplaykit_setCurrentAsyncTransaction:(_ASAsyncTransaction *)transaction
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedCurrentTransactionKey, transaction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)asyncdisplaykit_isAsyncTransactionContainer
{
  CFBooleanRef isContainerBool = (__bridge CFBooleanRef)objc_getAssociatedObject(self, ASAsyncTransactionIsContainerKey);
  BOOL isContainer = (isContainerBool == kCFBooleanTrue);
  return isContainer;
}

- (void)asyncdisplaykit_setAsyncTransactionContainer:(BOOL)isContainer
{
  objc_setAssociatedObject(self, ASAsyncTransactionIsContainerKey, (id)(isContainer ? kCFBooleanTrue : kCFBooleanFalse), OBJC_ASSOCIATION_ASSIGN);
}

- (ASAsyncTransactionContainerState)asyncdisplaykit_asyncTransactionContainerState
{
  return ([self.asyncdisplaykit_asyncLayerTransactions count] == 0) ? ASAsyncTransactionContainerStateNoTransactions : ASAsyncTransactionContainerStatePendingTransactions;
}

- (void)asyncdisplaykit_cancelAsyncTransactions
{
  // If there was an open transaction, commit and clear the current transaction. Otherwise:
  // (1) The run loop observer will try to commit a canceled transaction which is not allowed
  // (2) We leave the canceled transaction attached to the layer, dooming future operations
  _ASAsyncTransaction *currentTransaction = self.asyncdisplaykit_currentAsyncTransaction;
  [currentTransaction commit];
  self.asyncdisplaykit_currentAsyncTransaction = nil;

  for (_ASAsyncTransaction *transaction in [self.asyncdisplaykit_asyncLayerTransactions copy]) {
    [transaction cancel];
  }
}

- (_ASAsyncTransaction *)asyncdisplaykit_asyncTransaction
{
  _ASAsyncTransaction *transaction = self.asyncdisplaykit_currentAsyncTransaction;
  if (transaction == nil) {
    NSHashTable *transactions = self.asyncdisplaykit_asyncLayerTransactions;
    if (transactions == nil) {
      transactions = [NSHashTable hashTableWithOptions:NSPointerFunctionsObjectPointerPersonality];
      self.asyncdisplaykit_asyncLayerTransactions = transactions;
    }
    __weak CALayer *weakSelf = self;
    transaction = [[_ASAsyncTransaction alloc] initWithCallbackQueue:dispatch_get_main_queue() completionBlock:^(_ASAsyncTransaction *completedTransaction, BOOL cancelled) {
      __strong CALayer *self = weakSelf;
      if (self == nil) {
        return;
      }
      [transactions removeObject:completedTransaction];
      [self asyncdisplaykit_asyncTransactionContainerDidCompleteTransaction:completedTransaction];
    }];
    [transactions addObject:transaction];
    self.asyncdisplaykit_currentAsyncTransaction = transaction;
    [self asyncdisplaykit_asyncTransactionContainerWillBeginTransaction:transaction];
  }
  [[_ASAsyncTransactionGroup mainTransactionGroup] addTransactionContainer:self];
  return transaction;
}

- (CALayer *)asyncdisplaykit_parentTransactionContainer
{
  CALayer *containerLayer = self;
  while (containerLayer && !containerLayer.asyncdisplaykit_isAsyncTransactionContainer) {
    containerLayer = containerLayer.superlayer;
  }
  return containerLayer;
}

@end

@implementation UIView (ASAsyncTransactionContainer)

- (BOOL)asyncdisplaykit_isAsyncTransactionContainer
{
  return self.layer.asyncdisplaykit_isAsyncTransactionContainer;
}

- (void)asyncdisplaykit_setAsyncTransactionContainer:(BOOL)asyncTransactionContainer
{
  self.layer.asyncdisplaykit_asyncTransactionContainer = asyncTransactionContainer;
}

- (ASAsyncTransactionContainerState)asyncdisplaykit_asyncTransactionContainerState
{
  return self.layer.asyncdisplaykit_asyncTransactionContainerState;
}

- (void)asyncdisplaykit_cancelAsyncTransactions
{
  [self.layer asyncdisplaykit_cancelAsyncTransactions];
}

- (void)asyncdisplaykit_asyncTransactionContainerStateDidChange
{
  // No-op in the base class.
}

- (void)asyncdisplaykit_setCurrentAsyncTransaction:(_ASAsyncTransaction *)transaction
{
  self.layer.asyncdisplaykit_currentAsyncTransaction = transaction;
}

- (_ASAsyncTransaction *)asyncdisplaykit_currentAsyncTransaction
{
  return self.layer.asyncdisplaykit_currentAsyncTransaction;
}

@end
