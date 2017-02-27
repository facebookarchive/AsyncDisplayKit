//
//  ASCollectionViewFlowLayoutInspector.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionViewFlowLayoutInspector.h>
#import <AsyncDisplayKit/ASCollectionView.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASCollectionView+Undeprecated.h>
#import <AsyncDisplayKit/ASCollectionNode.h>

#define kDefaultItemSize CGSizeMake(50, 50)

#pragma mark - ASCollectionViewFlowLayoutInspector

@interface ASCollectionViewFlowLayoutInspector ()
@property (nonatomic, weak) UICollectionViewFlowLayout *layout;
@end
 
@implementation ASCollectionViewFlowLayoutInspector {
  struct {
    unsigned int implementsSizeRangeForHeader:1;
    unsigned int implementsReferenceSizeForHeader:1;
    unsigned int implementsSizeRangeForFooter:1;
    unsigned int implementsReferenceSizeForFooter:1;
    unsigned int implementsConstrainedSizeForNodeAtIndexPathDeprecated:1;
    unsigned int implementsConstrainedSizeForItemAtIndexPath:1;
  } _delegateFlags;
}

#pragma mark Lifecycle

- (instancetype)initWithFlowLayout:(UICollectionViewFlowLayout *)flowLayout;
{
  NSParameterAssert(flowLayout);
  
  self = [super init];
  if (self != nil) {
    _layout = flowLayout;
  }
  return self;
}

#pragma mark ASCollectionViewLayoutInspecting

- (void)didChangeCollectionViewDelegate:(id<ASCollectionDelegate>)delegate;
{
  if (delegate == nil) {
    memset(&_delegateFlags, 0, sizeof(_delegateFlags));
  } else {
    _delegateFlags.implementsSizeRangeForHeader = [delegate respondsToSelector:@selector(collectionNode:sizeRangeForHeaderInSection:)];
    _delegateFlags.implementsReferenceSizeForHeader = [delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)];
    _delegateFlags.implementsSizeRangeForFooter = [delegate respondsToSelector:@selector(collectionNode:sizeRangeForFooterInSection:)];
    _delegateFlags.implementsReferenceSizeForFooter = [delegate respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)];
    _delegateFlags.implementsConstrainedSizeForNodeAtIndexPathDeprecated = [delegate respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)];
    _delegateFlags.implementsConstrainedSizeForItemAtIndexPath = [delegate respondsToSelector:@selector(collectionNode:constrainedSizeForItemAtIndexPath:)];
  }
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange result = ASSizeRangeUnconstrained;
  if (_delegateFlags.implementsConstrainedSizeForItemAtIndexPath) {
    result = [collectionView.asyncDelegate collectionNode:collectionView.collectionNode constrainedSizeForItemAtIndexPath:indexPath];
  } else if (_delegateFlags.implementsConstrainedSizeForNodeAtIndexPathDeprecated) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    result = [collectionView.asyncDelegate collectionView:collectionView constrainedSizeForNodeAtIndexPath:indexPath];
#pragma clang diagnostic pop
  } else {
    // With 2.0 `collectionView:constrainedSizeForNodeAtIndexPath:` was moved to the delegate. Assert if not implemented on the delegate but on the data source
    ASDisplayNodeAssert([collectionView.asyncDataSource respondsToSelector:@selector(collectionView:constrainedSizeForNodeAtIndexPath:)] == NO, @"collectionView:constrainedSizeForNodeAtIndexPath: was moved from the ASCollectionDataSource to the ASCollectionDelegate.");
  }

  // If we got no size range:
  if (ASSizeRangeEqualToSizeRange(result, ASSizeRangeUnconstrained)) {
    // Use itemSize if they set it.
    CGSize itemSize = _layout.itemSize;
    if (CGSizeEqualToSize(itemSize, kDefaultItemSize) == NO) {
      result = ASSizeRangeMake(itemSize, itemSize);
    } else {
      // Compute constraint from scroll direction otherwise.
      result = NodeConstrainedSizeForScrollDirection(collectionView);
    }
  }
  
  return result;
}

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  ASSizeRange result = ASSizeRangeZero;
  if (ASObjectIsEqual(kind, UICollectionElementKindSectionHeader)) {
    if (_delegateFlags.implementsSizeRangeForHeader) {
      result = [[self delegateForCollectionView:collectionView] collectionNode:collectionView.collectionNode sizeRangeForHeaderInSection:indexPath.section];
    } else if (_delegateFlags.implementsReferenceSizeForHeader) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      CGSize exactSize = [[self delegateForCollectionView:collectionView] collectionView:collectionView layout:_layout referenceSizeForHeaderInSection:indexPath.section];
#pragma clang diagnostic pop
      result = ASSizeRangeMake(exactSize);
    } else {
      result = ASSizeRangeMake(_layout.headerReferenceSize);
    }
  } else if (ASObjectIsEqual(kind, UICollectionElementKindSectionFooter)) {
    if (_delegateFlags.implementsSizeRangeForFooter) {
      result = [[self delegateForCollectionView:collectionView] collectionNode:collectionView.collectionNode sizeRangeForFooterInSection:indexPath.section];
    } else if (_delegateFlags.implementsReferenceSizeForFooter) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      CGSize exactSize = [[self delegateForCollectionView:collectionView] collectionView:collectionView layout:_layout referenceSizeForFooterInSection:indexPath.section];
#pragma clang diagnostic pop
      result = ASSizeRangeMake(exactSize);
    } else {
      result = ASSizeRangeMake(_layout.footerReferenceSize);
    }
  } else {
    ASDisplayNodeFailAssert(@"Unexpected supplementary kind: %@", kind);
    return ASSizeRangeZero;
  }

  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    result.min.width = result.max.width = CGRectGetWidth(collectionView.bounds);
  } else {
    result.min.height = result.max.height = CGRectGetHeight(collectionView.bounds);
  }
  return result;
}

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryNodesOfKind:(NSString *)kind inSection:(NSUInteger)section
{
  ASSizeRange constraint = [self collectionView:collectionView constrainedSizeForSupplementaryNodeOfKind:kind atIndexPath:[NSIndexPath indexPathForItem:0 inSection:section]];
  if (_layout.scrollDirection == UICollectionViewScrollDirectionVertical) {
    return (constraint.max.height > 0 ? 1 : 0);
  } else {
    return (constraint.max.width > 0 ? 1 : 0);
  }
}

- (ASScrollDirection)scrollableDirections
{
  return (self.layout.scrollDirection == UICollectionViewScrollDirectionHorizontal) ? ASScrollDirectionHorizontalDirections : ASScrollDirectionVerticalDirections;
}

#pragma mark - Private helpers

- (id<ASCollectionDelegateFlowLayout>)delegateForCollectionView:(ASCollectionView *)collectionView
{
  return (id<ASCollectionDelegateFlowLayout>)collectionView.asyncDelegate;
}

@end
