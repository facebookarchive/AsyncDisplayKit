//
//  ASTableLayoutController.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASTableLayoutController.h>

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASAssert.h>

@interface ASTableLayoutController()
@end

@implementation ASTableLayoutController

- (instancetype)initWithTableView:(UITableView *)tableView
{
  if (!(self = [super init])) {
    return nil;
  }
  _tableView = tableView;
  return self;
}

#pragma mark - ASLayoutController

/**
 * IndexPath array for the element in the working range.
 */

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  if (rangeType == ASLayoutRangeTypeVisible) {
    return [NSSet setWithArray:[self indexPathsForVisibleRows]];
  } else {
    CGRect bounds = _tableView.bounds;
    ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];
    CGRect rangeBounds = CGRectExpandToRangeWithScrollableDirections(bounds, tuningParameters, ASScrollDirectionVerticalDirections, scrollDirection);
    NSArray *array = [_tableView indexPathsForRowsInRect:rangeBounds];
    return [NSSet setWithArray:array];
  }
}

- (void)allIndexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode visibleSet:(NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)visibleSet displaySet:(NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)displaySet preloadSet:(NSSet<NSIndexPath *> *__autoreleasing  _Nullable *)preloadSet
{
  if (displaySet == NULL || preloadSet == NULL || visibleSet == NULL) {
    return;
  }

  *visibleSet = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeVisible];
  *displaySet = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay];
  *preloadSet = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypePreload];
  return;
}

#pragma mark - Private

- (NSArray<NSIndexPath *> *)indexPathsForVisibleRows
{
  NSArray *indexPaths = [_tableView indexPathsForVisibleRows];
  
  // In some cases (grouped-style tables with particular geometry) indexPathsForVisibleRows will return extra index paths.
  // This is a very serious issue because we rely on the fact that any node that is marked Visible is hosted inside of a cell,
  // or else we may not mark it invisible before the node is released. See testIssue2252.
  // Calling indexPathForCell: and cellForRowAtIndexPath: are both pretty expensive – this is the quickest approach we have.
  // It would be possible to cache this NSPredicate as an ivar, but that would require unsafeifying self and calling @c bounds
  // for each item. Since the performance cost is pretty small, prefer simplicity.
  if (_tableView.style == UITableViewStyleGrouped && indexPaths.count != _tableView.visibleCells.count) {
    CGRect bounds = _tableView.bounds;
    indexPaths = [indexPaths filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSIndexPath *indexPath, NSDictionary<NSString *,id> * _Nullable bindings) {
      return CGRectIntersectsRect(bounds, [_tableView rectForRowAtIndexPath:indexPath]);
    }]];
  }
  
  return indexPaths;
}

@end
