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
#import <AsyncDisplayKit/ASCollectionContentAttributes.h>
#import <AsyncDisplayKit/ASCollectionNode.h>
#import <AsyncDisplayKit/ASDataControllerLayoutContext.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

@interface ASCollectionLayout () {
  ASDN::Mutex __instanceLock__; // Non-recursive mutex, ftw!
  
  // Main thread only.
  ASCollectionContentAttributes *_currentContentAttributes;
  
  // The pending content calculated ahead of time, if any.
  ASCollectionContentAttributes *_pendingContentAttributes;
  // The context used to calculate _pendingContentAttributes
  ASDataControllerLayoutContext *_layoutContextForPendingContentAttributes;
}

@end

@implementation ASCollectionLayout

- (instancetype)init
{
  return [super init];
}

- (ASCollectionContentAttributes *)currentContentAttributes
{
  ASDisplayNodeAssertMainThread();
  return _currentContentAttributes;
}

- (void)setCurrentContentAttributes:(ASCollectionContentAttributes *)newAttrs
{
  ASDisplayNodeAssertMainThread();
  if (! ASObjectIsEqual(_currentContentAttributes, newAttrs)) {
    _currentContentAttributes = newAttrs;
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
  ASCollectionContentAttributes *attrs = [self calculateLayoutForLayoutContext:context];
  
  ASDN::MutexLocker l(__instanceLock__);
  _pendingContentAttributes = attrs;
  _layoutContextForPendingContentAttributes = context;
}

#pragma mark - UICollectionViewLayout overrides

- (void)prepareLayout
{
  ASDisplayNodeAssertMainThread();
  ASDataControllerLayoutContext *context =  [self layoutContextWithElementMap:[_dataSource elementMapForCollectionLayout:self]];
  
  ASCollectionContentAttributes *attrs;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_pendingContentAttributes != nil && ASObjectIsEqual(_layoutContextForPendingContentAttributes, context)) {
      // Looks like we can use the pending attrs. Great!
      attrs = _pendingContentAttributes;
      _pendingContentAttributes = nil;
      _layoutContextForPendingContentAttributes = nil;
    }
  }
  
  if (attrs == nil) {
    attrs = [self calculateLayoutForLayoutContext:context];
  }
  
  _currentContentAttributes = attrs;
}

- (void)invalidateLayout
{
  ASDisplayNodeAssertMainThread();
  [super invalidateLayout];
  _currentContentAttributes = nil;
}

- (CGSize)collectionViewContentSize
{
  ASDisplayNodeAssertMainThread();
  return _currentContentAttributes.contentSize;
}

#pragma mark - Subclass hooks

- (ASCollectionContentAttributes *)calculateLayoutForLayoutContext:(ASDataControllerLayoutContext *)context
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
