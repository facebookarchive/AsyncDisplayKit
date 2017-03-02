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
  CGRect bounds = _tableView.bounds;

  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];
  CGRect rangeBounds = CGRectExpandToRangeWithScrollableDirections(bounds, tuningParameters, ASScrollDirectionVerticalDirections, scrollDirection);
  NSArray *array = [_tableView indexPathsForRowsInRect:rangeBounds];
  return [NSSet setWithArray:array];
}

- (void)allIndexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSSet **)displaySet preloadSet:(NSSet **)preloadSet
{
  if (displaySet == NULL || preloadSet == NULL) {
    return;
  }

  *displaySet = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay];
  *preloadSet = [self indexPathsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypePreload];
  return;
}

@end
