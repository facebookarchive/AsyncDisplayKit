//
//  ASCollectionLayout.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayout.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCollectionLayoutContext+Private.h>
#import <AsyncDisplayKit/ASCollectionLayoutDelegate.h>
#import <AsyncDisplayKit/ASCollectionLayoutState.h>
#import <AsyncDisplayKit/ASCollectionNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

@interface ASCollectionLayout () <ASDataControllerLayoutDelegate> {
  ASDN::Mutex __instanceLock__; // Non-recursive mutex, ftw!
  
  // Main thread only.
  ASCollectionLayoutState *_state;
  
  // The pending state calculated ahead of time, if any.
  ASCollectionLayoutState *_pendingState;
  // The context used to calculate _pendingState
  ASCollectionLayoutContext *_layoutContextForPendingState;
  
  BOOL _layoutDelegateImplementsAdditionalInfoForLayoutWithElements;
}

@end

@implementation ASCollectionLayout

- (instancetype)initWithLayoutDelegate:(id<ASCollectionLayoutDelegate>)layoutDelegate
{
  self = [super init];
  if (self) {
    ASDisplayNodeAssertNotNil(layoutDelegate, @"Collection layout delegate cannot be nil");
    _layoutDelegate = layoutDelegate;
    _layoutDelegateImplementsAdditionalInfoForLayoutWithElements = [layoutDelegate respondsToSelector:@selector(additionalInfoForLayoutWithElements:)];
  }
  return self;
}

#pragma mark - ASDataControllerLayoutDelegate

- (id)layoutContextWithElements:(ASElementMap *)elements
{
  ASDisplayNodeAssertMainThread();
  id additionalInfo = nil;
  if (_layoutDelegateImplementsAdditionalInfoForLayoutWithElements) {
    additionalInfo = [_layoutDelegate additionalInfoForLayoutWithElements:elements];
  }
  return [[ASCollectionLayoutContext alloc] initWithViewportSize:[self viewportSize] elements:elements additionalInfo:additionalInfo];
}

- (void)prepareLayoutWithContext:(id)context
{
  ASCollectionLayoutState *state = [_layoutDelegate calculateLayoutWithContext:context];
  
  ASDN::MutexLocker l(__instanceLock__);
  _pendingState = state;
  _layoutContextForPendingState = context;
}

#pragma mark - UICollectionViewLayout overrides

- (void)prepareLayout
{
  ASDisplayNodeAssertMainThread();
  [super prepareLayout];
  ASCollectionLayoutContext *context = [self layoutContextWithElements:_collectionNode.visibleElements];
  
  ASCollectionLayoutState *state = nil;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_pendingState != nil && ASObjectIsEqual(_layoutContextForPendingState, context)) {
      // Looks like we can use the pending state. Great!
      state = _pendingState;
      _pendingState = nil;
      _layoutContextForPendingState = nil;
    }
  }
  
  if (state == nil) {
    state = [_layoutDelegate calculateLayoutWithContext:context];
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
  ASDisplayNodeAssertNotNil(_state, @"Collection layout state should not be nil at this point");
  return _state.contentSize;
}

- (NSArray<UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect
{
  NSMutableArray *attributesInRect = [NSMutableArray array];
  NSMapTable *attrsMap = _state.elementToLayoutArrtibutesMap;
  for (ASCollectionElement *element in attrsMap) {
    UICollectionViewLayoutAttributes *attrs = [attrsMap objectForKey:element];
    if (CGRectIntersectsRect(rect, attrs.frame)) {
      [attributesInRect addObject:attrs];
    }
  }
  return attributesInRect;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionLayoutState *state = _state;
  ASCollectionElement *element = [state.elements elementForItemAtIndexPath:indexPath];
  return [state.elementToLayoutArrtibutesMap objectForKey:element];
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath
{
  ASCollectionLayoutState *state = _state;
  ASCollectionElement *element = [state.elements supplementaryElementOfKind:elementKind atIndexPath:indexPath];
  return [state.elementToLayoutArrtibutesMap objectForKey:element];
}

#pragma mark - Private methods

- (CGSize)viewportSize
{
  ASCollectionNode *collectionNode = _collectionNode;
  if (collectionNode != nil && !collectionNode.isNodeLoaded) {
    // TODO consider calculatedSize as well
    return collectionNode.threadSafeBounds.size;
  } else {
    ASDisplayNodeAssertMainThread();
    return self.collectionView.bounds.size;
  }
}

@end
