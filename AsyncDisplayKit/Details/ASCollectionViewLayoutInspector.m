//
//  ASCollectionViewLayoutInspector.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 11/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASCollectionViewLayoutInspector.h"

#import "ASCollectionView.h"
#import "ASCollectionView+Undeprecated.h"

#pragma mark - Helper Functions

// Returns a constrained size to let the cells layout itself as far as possible based on the scrollable direction
// of the collection view
ASSizeRange NodeConstrainedSizeForScrollDirection(ASCollectionView *collectionView) {
  CGSize maxSize = collectionView.bounds.size;
  if (ASScrollDirectionContainsHorizontalDirection(collectionView.scrollableDirections)) {
    maxSize.width = CGFLOAT_MAX;
  } else {
    maxSize.height = CGFLOAT_MAX;
  }
  return ASSizeRangeMake(CGSizeZero, maxSize);
}

#pragma mark - ASCollectionViewLayoutInspector

@implementation ASCollectionViewLayoutInspector {
  struct {
    unsigned int implementsConstrainedSizeForNodeAtIndexPathDeprecated:1;
    unsigned int implementsConstrainedSizeForNodeAtIndexPath:1;
  } _delegateFlags;
}

#pragma mark Lifecycle

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  self = [super init];
  if (self != nil) {
    [self didChangeCollectionViewDelegate:collectionView.asyncDelegate];
  }
  return self;
}

#pragma mark ASCollectionViewLayoutInspecting

- (void)didChangeCollectionViewDelegate:(id<ASCollectionDelegate>)delegate
{
  if (delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.implementsConstrainedSizeForNodeAtIndexPathDeprecated = [delegate respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)];
    _delegateFlags.implementsConstrainedSizeForNodeAtIndexPath = [delegate respondsToSelector:@selector(collectionNode:constrainedSizeForItemAtIndexPath:)];
  }
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  if (_delegateFlags.implementsConstrainedSizeForNodeAtIndexPath) {
    return [collectionView.asyncDelegate collectionNode:collectionView.collectionNode constrainedSizeForItemAtIndexPath:indexPath];
  } else if (_delegateFlags.implementsConstrainedSizeForNodeAtIndexPathDeprecated) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [collectionView.asyncDelegate collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath];
#pragma clang diagnostic pop
  } else {
    // With 2.0 `collectionView:constrainedSizeForNodeAtIndexPath:` was moved to the delegate. Assert if not implemented on the delegate but on the data source
    ASDisplayNodeAssert([collectionView.asyncDataSource respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)] == NO, @"collectionView:constrainedSizeForNodeAtIndexPath: was moved from the ASCollectionDataSource to the ASCollectionDelegate.");
  }
  
  return NodeConstrainedSizeForScrollDirection(collectionView);
}

- (ASScrollDirection)scrollableDirections
{
  return ASScrollDirectionNone;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssert(NO, @"To support supplementary nodes in ASCollectionView, it must have a layoutInspector for layout inspection. (See ASCollectionViewFlowLayoutInspector for an example.)");
  return ASSizeRangeMake(CGSizeZero, CGSizeZero);
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  ASDisplayNodeAssert(NO, @"To support supplementary nodes in ASCollectionView, it must have a layoutInspector for layout inspection. (See ASCollectionViewFlowLayoutInspector for an example.)");
  return 0;
}

@end
