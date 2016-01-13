/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCollectionViewLayoutController.h"

#include <vector>

#import "ASAssert.h"
#import "ASCollectionView.h"
#import "CGRect+ASConvenience.h"
#import "UICollectionViewLayout+ASConvenience.h"

struct ASRangeGeometry {
  CGRect rangeBounds;
  CGRect updateBounds;
};
typedef struct ASRangeGeometry ASRangeGeometry;


#pragma mark -
#pragma mark ASCollectionViewLayoutController

@interface ASCollectionViewLayoutController ()
{
  @package
  ASCollectionView * __weak _collectionView;
  UICollectionViewLayout * __strong _collectionViewLayout;
  ASScrollDirection _scrollableDirections;
}
@end

@implementation ASCollectionViewLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _scrollableDirections = [collectionView scrollableDirections];
  _collectionView = collectionView;
  _collectionViewLayout = [collectionView collectionViewLayout];
  return self;
}

@end

@implementation ASCollectionViewLayoutControllerStable
{
  std::vector<CGRect> _updateRangeBoundsIndexedByRangeType;
}

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  if (!(self = [super initWithCollectionView:collectionView])) {
    return nil;
  }
  
  _updateRangeBoundsIndexedByRangeType = std::vector<CGRect>(ASLayoutRangeTypeCount);
  return self;
}

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeType:(ASLayoutRangeType)rangeType
{
  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeType:rangeType];
  ASRangeGeometry rangeGeometry = [self rangeGeometryWithScrollDirection:scrollDirection tuningParameters:tuningParameters];
  _updateRangeBoundsIndexedByRangeType[rangeType] = rangeGeometry.updateBounds;
  return [self indexPathsForItemsWithinRangeBounds:rangeGeometry.rangeBounds];
}

- (NSSet *)indexPathsForItemsWithinRangeBounds:(CGRect)rangeBounds
{
  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];
  NSArray *layoutAttributes = [_collectionViewLayout layoutAttributesForElementsInRect:rangeBounds];
  for (UICollectionViewLayoutAttributes *la in layoutAttributes) {
    if (la.representedElementCategory == UICollectionElementCategoryCell) {
      [indexPathSet addObject:la.indexPath];
    }
  }
  return indexPathSet;
}

- (ASRangeGeometry)rangeGeometryWithScrollDirection:(ASScrollDirection)scrollDirection
                                   tuningParameters:(ASRangeTuningParameters)tuningParameters
{
  CGRect rangeBounds = _collectionView.bounds;
  CGRect updateBounds = _collectionView.bounds;
  
  // Scrollable directions can change for non-flow layouts
  if ([_collectionViewLayout asdk_isFlowLayout] == NO) {
    _scrollableDirections = [_collectionView scrollableDirections];
  }
  
  rangeBounds = CGRectExpandToRangeWithScrollableDirections(rangeBounds, tuningParameters, _scrollableDirections, scrollDirection);
  
  ASRangeTuningParameters updateTuningParameters = tuningParameters;
  updateTuningParameters.leadingBufferScreenfuls = MIN(updateTuningParameters.leadingBufferScreenfuls * 0.5, 0.95);
  updateTuningParameters.trailingBufferScreenfuls = MIN(updateTuningParameters.trailingBufferScreenfuls * 0.5, 0.95);
  
  updateBounds = CGRectExpandToRangeWithScrollableDirections(updateBounds, updateTuningParameters, _scrollableDirections, scrollDirection);

  return {rangeBounds, updateBounds};
}

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths rangeType:(ASLayoutRangeType)rangeType
{
  CGSize viewportSize = [self viewportSize];
  CGRect updateRangeBounds = _updateRangeBoundsIndexedByRangeType[rangeType];
  if (CGRectIsEmpty(updateRangeBounds)) {
    return YES;
  }
  
  CGRect currentBounds = _collectionView.bounds;
  if (CGRectIsEmpty(currentBounds)) {
    currentBounds = CGRectMake(0, 0, viewportSize.width, viewportSize.height);
  }
  
  if (CGRectContainsRect(updateRangeBounds, currentBounds)) {
    return NO;
  } else {
    return YES;
  }
}

@end


@implementation ASCollectionViewLayoutControllerBeta

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeType:(ASLayoutRangeType)rangeType
{
  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeType:rangeType];
  CGRect rangeBounds = [self rangeBoundsWithScrollDirection:scrollDirection rangeTuningParameters:tuningParameters];
  return [self indexPathsForItemsWithinRangeBounds:rangeBounds];
}

- (NSSet *)indexPathsForItemsWithinRangeBounds:(CGRect)rangeBounds
{
  NSArray *layoutAttributes = [_collectionViewLayout layoutAttributesForElementsInRect:rangeBounds];
  NSMutableSet *indexPathSet = [NSMutableSet setWithCapacity:layoutAttributes.count];
  for (UICollectionViewLayoutAttributes *la in layoutAttributes) {
    //ASDisplayNodeAssert(![indexPathSet containsObject:la.indexPath], @"Shouldn't already contain indexPath");
    ASDisplayNodeAssert(la.representedElementCategory != UICollectionElementCategoryDecorationView, @"UICollectionView decoration views are not supported by ASCollectionView");
    [indexPathSet addObject:la.indexPath];
  }
  return indexPathSet;
}

- (CGRect)rangeBoundsWithScrollDirection:(ASScrollDirection)scrollDirection
                   rangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  CGRect rect = _collectionView.bounds;
  
  // Scrollable directions can change for non-flow layouts
  if ([_collectionViewLayout asdk_isFlowLayout] == NO) {
    _scrollableDirections = [_collectionView scrollableDirections];
  }
  
  return CGRectExpandToRangeWithScrollableDirections(rect, tuningParameters, _scrollableDirections, scrollDirection);
}

@end
