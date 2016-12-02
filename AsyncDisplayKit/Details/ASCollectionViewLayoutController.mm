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
#import "CoreGraphics+ASConvenience.h"
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
}
@end

@implementation ASCollectionViewLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  if (!(self = [super init])) {
    return nil;
  }
  
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

    // Manually filter out elements that don't intersect the range bounds.
    // If a layout returns elements outside the requested rect this can be a huge problem.
    // For instance in a paging flow, you may only want to preload 3 pages (one center, one on each side)
    // but if flow layout includes the 4th page (which it does! as of iOS 9&10), you will preload a 4th
    // page as well.
    if (CATransform3DIsIdentity(la.transform3D) && CGRectIntersectsRect(la.frame, rangeBounds) == NO) {
      continue;
    }
    [indexPathSet addObject:la.indexPath];
  }

  return indexPathSet;
}

- (CGRect)rangeBoundsWithScrollDirection:(ASScrollDirection)scrollDirection
                   rangeTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  CGRect rect = _collectionView.bounds;
  
  return CGRectExpandToRangeWithScrollableDirections(rect, tuningParameters, [_collectionView scrollableDirections], scrollDirection);
}

@end
