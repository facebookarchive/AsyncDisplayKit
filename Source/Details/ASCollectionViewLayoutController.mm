//
//  ASCollectionViewLayoutController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionViewLayoutController.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCollectionView.h>
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>
#import <AsyncDisplayKit/UICollectionViewLayout+ASConvenience.h>

struct ASRangeGeometry {
  CGRect rangeBounds;
  CGRect updateBounds;
};
typedef struct ASRangeGeometry ASRangeGeometry;


#pragma mark -
#pragma mark ASCollectionViewLayoutController

@interface ASCollectionViewLayoutController ()
{
  ASCollectionView * __weak _collectionView;
}
@end

@implementation ASCollectionViewLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _collectionView = collectionView;
  return self;
}

- (void)indexPathsForScrolling:(ASScrollDirection)scrollDirection
                     rangeMode:(ASLayoutRangeMode)rangeMode
             visibleIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outVisible
             displayIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outDisplay
             preloadIndexPaths:(out NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)outPreload
{
  CGRect visibleRect = _collectionView.bounds;
  CGRect preloadRect = CGRectExpandToRangeWithScrollableDirections(visibleRect, [self tuningParametersForRangeMode:rangeMode rangeType:ASLayoutRangeTypePreload], ASScrollDirectionVerticalDirections, scrollDirection);
  CGRect displayRect = CGRectExpandToRangeWithScrollableDirections(visibleRect, [self tuningParametersForRangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay], ASScrollDirectionVerticalDirections, scrollDirection);
  ASDisplayNodeAssert(CGRectContainsRect(displayRect, visibleRect), @"Display rect should contain visible rect.");
  ASDisplayNodeAssert(CGRectContainsRect(preloadRect, displayRect), @"Preload rect should contain display rect.");
  
  /**
   * To get this quickly, we ask our layout to get the preload index paths, and
   * we filter that set down to get the display index paths, and filter that set down
   * to get the visible index paths.
   */
  NSArray<UICollectionViewLayoutAttributes *> *rawAttributes = [_collectionView.collectionViewLayout layoutAttributesForElementsInRect:preloadRect];
  
  NSMutableSet *preloadIndexPaths = [NSMutableSet set];
  NSMutableSet *visibleIndexPaths = [NSMutableSet set];
  NSMutableSet *displayIndexPaths = [NSMutableSet set];
  for (UICollectionViewLayoutAttributes *attr in rawAttributes) {
    CGRect frame = attr.frame;
    NSIndexPath *indexPath = attr.indexPath;
    if (CGRectIntersectsRect(frame, preloadRect)) {
      [preloadIndexPaths addObject:indexPath];
      if (CGRectIntersectsRect(displayRect, frame)) {
        [displayIndexPaths addObject:indexPath];
        if (CGRectIntersectsRect(visibleRect, frame)) {
          [visibleIndexPaths addObject:indexPath];
        }
      }
    }
  }
  
  *outPreload = preloadIndexPaths;
  *outVisible = visibleIndexPaths;
  *outDisplay = displayIndexPaths;
}

@end
