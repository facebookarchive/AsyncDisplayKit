//
//  ASCollectionSectionController.m
//  Sample
//
//  Created by Adlai Holler on 12/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASCollectionSectionController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASCollectionSectionController ()
@property (nonatomic, strong, readonly) dispatch_queue_t diffingQueue;

/// The items that have been diffed and are waiting to be submitted to the collection view.
/// Should always be accessed on the diffing queue, and should never be accessed
/// before the initial items are read (in -numberOfItems).
@property (nonatomic, copy) NSArray *pendingItems;

@property (nonatomic) BOOL initialItemsRead;
@end

@implementation ASCollectionSectionController
@synthesize diffingQueue = _diffingQueue;

- (NSInteger)numberOfItems
{
  if (_initialItemsRead == NO) {
    _pendingItems = self.items;
    _initialItemsRead = YES;
  }
  return self.items.count;
}

- (dispatch_queue_t)diffingQueue
{
  if (_diffingQueue == nil) {
    _diffingQueue = dispatch_queue_create("ASCollectionSectionController.diffingQueue", DISPATCH_QUEUE_SERIAL);
  }
  return _diffingQueue;
}

- (void)setItems:(NSArray *)newItems animated:(BOOL)animated completion:(void(^)())completion
{
  ASDisplayNodeAssertMainThread();
  newItems = [newItems copy];
  if (!self.initialItemsRead) {
    _items = newItems;
    if (completion) {
      completion();
    }
    return;
  }

  BOOL wasEmpty = (self.items.count == 0);

  dispatch_async(self.diffingQueue, ^{
    IGListIndexSetResult *result = IGListDiff(self.pendingItems, newItems, IGListDiffPointerPersonality);
    self.pendingItems = newItems;
    dispatch_async(dispatch_get_main_queue(), ^{
      id<IGListCollectionContext> ctx = self.collectionContext;
      [ctx performBatchAnimated:animated updates:^{
        [ctx insertInSectionController:(id)self atIndexes:result.inserts];
        [ctx deleteInSectionController:(id)self atIndexes:result.deletes];
        _items = newItems;
      } completion:^(BOOL finished) {
        if (completion) {
          completion();
        }
        // WORKAROUND for https://github.com/Instagram/IGListKit/issues/378
        if (wasEmpty) {
          [(IGListAdapter *)ctx performUpdatesAnimated:NO completion:nil];
        }
      }];
    });
  });
}

@end
