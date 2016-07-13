//
//  ASCollectionViewLayoutController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASCollectionViewLayoutController.h"

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

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];
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
