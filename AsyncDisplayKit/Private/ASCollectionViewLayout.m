//
//  ASCollectionViewLayout.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/21/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASCollectionViewLayout.h"
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASCellNode.h>
#import <AsyncDisplayKit/ASCollectionLayout.h>
#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASMainSerialQueue.h>
#import <stdatomic.h>

@interface ASCollectionViewLayout ()
@property (nonatomic, strong) ASCollectionLayout *displayedLayout;
@property (nonatomic, strong) ASCollectionLayout *pendingLayout;
@property (nonatomic, nullable, copy) dispatch_block_t cancelCurrentWork;
@property (nonatomic, strong) dispatch_group_t workGroup;
@property (nonatomic, strong) ASMainSerialQueue *mainSerialQueue;
@end

@implementation ASCollectionViewLayout

- (instancetype)init
{
  if (self = [super init]) {
    _mainSerialQueue = [[ASMainSerialQueue alloc] init];
  }
  return self;
}

- (void)prepareLayout
{
  [self scheduleLayout];
  [super prepareLayout];
  [self applyLatestLayout];
}

- (CGSize)collectionViewContentSize
{
  return self.displayedLayout.collectionViewContentSize;
}

- (NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  return [self.displayedLayout layoutAttributesForElementsInRect:rect];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  return [self.displayedLayout layoutAttributesForItemAtIndexPath:indexPath];
}

- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context
{
  [super invalidateLayoutWithContext:context];
  self.displayedLayout = nil;
  [self.collectionNode waitUntilAllUpdatesAreCommitted];
  [self cancelLayout];
  [self scheduleLayout];
}

#pragma mark - Private

// If layout is already scheduled, ignores.
- (void)scheduleLayout
{
  ASDisplayNodeAssertMainThread();
  if (_cancelCurrentWork) {
    return;
  }
  
  ASCollectionNode *node = self.collectionNode;
  
  // Create local canceled flag & dispatch_group
  // Our ivars are main-thread-only.
  __block atomic_bool canceled = ATOMIC_VAR_INIT(NO);
  dispatch_group_t workGroup = dispatch_group_create();
  
  _workGroup = workGroup;
  _cancelCurrentWork = ^{
    atomic_store(&canceled, YES);
  };
  asdisplaynode_iscancelled_block_t canceledBlock = ^{
    return atomic_load(&canceled);
  };
  
  // TODO: Copy node contexts from data controller
  NSDictionary<NSString *, NSArray<NSArray<ASCollectionElement *> *> *> *elements = nil;
  
  // We enter the group when we schedule the work.
  dispatch_group_enter(workGroup);
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    if (canceledBlock) {
      return;
    }
    
    [ASCollectionViewLayout
     getLayoutFromNode:node
     cancelled:canceledBlock
     completion:^(ASLayout *layout) {
       ASCollectionLayout *collectionLayout = [[ASCollectionLayout alloc] initWithLayout:layout elements:elements];
       // We got our layout, but we're still off-main. Enqueue back to main. Not worth checking canceled till we're in there.
       [_mainSerialQueue performBlockOnMainThread:^{
         if (!canceledBlock()) {
           [self didReceiveLayout:collectionLayout];
         }
       }];
       // Exit immediately after enqueuing to main serial queue.
       dispatch_group_leave(workGroup);
     }];
  });
}

- (void)cancelLayout
{
  ASDisplayNodeAssertMainThread();
  if (_cancelCurrentWork) {
    _cancelCurrentWork();
  }
  
  [self cleanupState];
}

- (void)didReceiveLayout:(ASCollectionLayout *)layout
{
  ASDisplayNodeAssertMainThread();
  _pendingLayout = layout;
  [self cleanupState];
}

// Called after cancel or finish
- (void)cleanupState
{
  ASDisplayNodeAssertMainThread();
  
  _workGroup = nil;
  _cancelCurrentWork = nil;
}

// Blocks if needed, and then copies latest layout into displayedLayout
- (void)applyLatestLayout
{
  ASDisplayNodeAssertMainThread();
  // Wait for async process to finish
  dispatch_group_wait(_workGroup, DISPATCH_TIME_FOREVER);
  // TODO: Improve the MainSerialQueue API so we can be more explicit.
  [_mainSerialQueue performBlockOnMainThread:^{}];
}

#pragma mark - Helpers

// The actual work method, run off-main. You can call completion from any thread.
+ (void)getLayoutFromNode:(ASCollectionNode *)collectionNode cancelled:(asdisplaynode_iscancelled_block_t)isCancelled completion:(void(^)(ASLayout *))completion
{
  ASLayout *layout = [collectionNode layoutThatFits:ASSizeRangeMake(collectionNode.bounds.size)];
  ASDisplayNodeAssert(CGPointEqualToPoint(layout.position, CGPointZero), @"Expected collection layout to have origin at 0.");
  completion(layout);
}

@end
