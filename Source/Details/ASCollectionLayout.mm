//
//  ASCollectionLayout.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayout.h>
#import <AsyncDisplayKit/ASCollectionLayout+Subclasses.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASDataControllerLayoutContext.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

@interface ASCollectionLayout () {
  ASDN::Mutex __instanceLock__; // Non-recursive mutex, ftw!
  
  // Main thread only.
  ASCollectionLayoutState *_state;
  
  // The pending state calculated ahead of time, if any.
  ASCollectionLayoutState *_pendingState;
  // The context used to calculate _pendingState
  ASDataControllerLayoutContext *_layoutContextForPendingState;
}

@end

@implementation ASCollectionLayout

- (instancetype)init
{
  return [super init];
}

- (ASCollectionLayoutState *)state
{
  ASDisplayNodeAssertMainThread();
  return _state;
}

- (void)setState:(ASCollectionLayoutState *)newState
{
  ASDisplayNodeAssertMainThread();
  if (! ASObjectIsEqual(_state, newState)) {
    _state = newState;
  }
}

#pragma mark - ASDataControllerLayoutDelegate

- (ASDataControllerLayoutContext *)layoutContextWithElementMap:(ASElementMap *)map
{
  ASDisplayNodeAssertMainThread();
  return [[ASDataControllerLayoutContext alloc] initWithViewportSize:[self viewportSize] elementMap:map];
}

- (void)prepareLayoutForLayoutContext:(ASDataControllerLayoutContext *)context
{
  ASCollectionLayoutState *state = [self calculateLayoutForLayoutContext:context];
  
  ASDN::MutexLocker l(__instanceLock__);
  _pendingState = state;
  _layoutContextForPendingState = context;
}

#pragma mark - UICollectionViewLayout overrides

- (void)prepareLayout
{
  ASDisplayNodeAssertMainThread();
  ASDataControllerLayoutContext *context =  [self layoutContextWithElementMap:[_dataSource elementMapForCollectionLayout:self]];
  
  ASCollectionLayoutState *state;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_pendingState != nil && ASObjectIsEqual(_layoutContextForPendingState, context)) {
      // Looks like we can use the pending attrs. Great!
      state = _pendingState;
      _pendingState = nil;
      _layoutContextForPendingState = nil;
    }
  }
  
  if (state == nil) {
    state = [self calculateLayoutForLayoutContext:context];
  }
  
  _state = state;
}

- (void)invalidateLayout
{
  ASDisplayNodeAssertMainThread();
  [super invalidateLayout];
  _state = nil;
}

- (CGSize)collectionViewContentSize
{
  ASDisplayNodeAssertMainThread();
  return _state.contentSize;
}

#pragma mark - Subclass hooks

- (ASCollectionLayoutState *)calculateLayoutForLayoutContext:(ASDataControllerLayoutContext *)context
{
  // Subclass hooks
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  return nil;
}

#pragma mark - Private methods

- (CGSize)viewportSize
{
  ASCollectionNode *collectionNode = self.collectionNode;
  if (collectionNode != nil && !collectionNode.isNodeLoaded) {
    // TODO consider calculatedSize as well
    return collectionNode.threadSafeBounds.size;
  } else {
    ASDisplayNodeAssertMainThread();
    return self.collectionView.bounds.size;
  }
}

@end
