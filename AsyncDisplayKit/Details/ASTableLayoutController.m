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
@property (nonatomic, strong) NSIndexPath *minVisibleIndexPath;
@property (nonatomic, strong) NSIndexPath *maxVisibleIndexPath;
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

#pragma mark - Visible Indices

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths
{
  _minVisibleIndexPath = [ASTableLayoutController fastArrayMin:indexPaths];
  _maxVisibleIndexPath = [ASTableLayoutController fastArrayMax:indexPaths];
}

/**
 * IndexPath array for the element in the working range.
 */

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  if (_minVisibleIndexPath == nil) {
    return [NSSet set];
  }

  CGSize viewportSize = [self viewportSize];

  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];

  ASDirectionalScreenfulBuffer directionalBuffer = ASDirectionalScreenfulBufferVertical(scrollDirection, tuningParameters);
  
  NSIndexPath *startPath = [self findIndexPathAtDistance:(-directionalBuffer.negativeDirection * viewportSize.height)
                                          fromIndexPath:_minVisibleIndexPath];
  
  NSIndexPath *endPath   = [self findIndexPathAtDistance:(directionalBuffer.positiveDirection * viewportSize.height)
                                          fromIndexPath:_maxVisibleIndexPath];

  NSSet *indexPaths = [self indexPathsFromIndexPath:startPath toIndexPath:endPath];
  return indexPaths;
}

#pragma mark - Utility

- (NSIndexPath *)findIndexPathAtDistance:(CGFloat)distance fromIndexPath:(NSIndexPath *)start
{
  BOOL downward = (distance >= 0);
  CGRect startRowRect = [_tableView rectForRowAtIndexPath:start];
  CGFloat targetY = distance + (downward ? CGRectGetMaxY(startRowRect) : CGRectGetMinY(startRowRect));

  // Before first row.
  NSIndexPath *firstIndexPath = [self firstIndexPathInTableView];
  if (targetY <= CGRectGetMaxY([_tableView rectForRowAtIndexPath:firstIndexPath])) {
    return firstIndexPath;
  }

  // After last row.
  NSIndexPath *lastIndexPath = [self lastIndexPathInTableView];
  if (targetY >= CGRectGetMinY([_tableView rectForRowAtIndexPath:lastIndexPath])) {
    return lastIndexPath;
  }

  /**
   * There may not be a row at any given EXACT point, for these possible reasons:
   * - There is a section header/footer at that point.
   * - That point is beyond the start/end of the table content. (Handled above)
   *
   * Solution: Make a search rect, and if we don't
   * find any rows, keep doubling its height and searching again. In practice,
   * this will virtually always find a row on the first try (unless you have a 
   * tall section header and we land near the middle.)
   */
  NSIndexPath *result = nil;
  for (CGRect searchRect = [ASTableLayoutController initialSearchRectDownward:downward targetY:targetY];
       // continue while result is nil
       result == nil;
       // grow search rect after each loop
       searchRect = [ASTableLayoutController growSearchRect:searchRect downward:downward]) {
    NSArray *rows = [_tableView indexPathsForRowsInRect:searchRect];
    if (downward) {
      result = [ASTableLayoutController fastArrayMin:rows];
    } else {
      result = [ASTableLayoutController fastArrayMax:rows];
    }
  }
  return result;
}

- (NSSet<NSIndexPath *> *)indexPathsFromIndexPath:(NSIndexPath *)startIndexPath toIndexPath:(NSIndexPath *)endIndexPath
{
  ASDisplayNodeAssert([startIndexPath compare:endIndexPath] != NSOrderedDescending, @"Index paths must be in nondescending order. Start: %@, end %@", startIndexPath, endIndexPath);

  NSMutableSet *result = [NSMutableSet set];
  NSInteger const endSection = endIndexPath.section;
  NSInteger i = startIndexPath.row;
  for (NSInteger s = startIndexPath.section; s <= endSection; s++) {
    // If end section, row <= end.item. Otherwise (row <= sectionRowCount - 1).
    NSInteger const rowLimit = (s == endSection ? endIndexPath.row : ([_tableView numberOfRowsInSection:s] - 1));
    for (; i <= rowLimit; i++) {
      [result addObject:[NSIndexPath indexPathForRow:i inSection:s]];
    }
    i = 0;
  }
  return result;
}

- (nullable NSIndexPath *)firstIndexPathInTableView
{
  NSInteger sectionCount = _tableView.numberOfSections;
  for (NSInteger s = 0; s < sectionCount; s++) {
    if ([_tableView numberOfRowsInSection:s] > 0) {
      return [NSIndexPath indexPathForRow:0 inSection:s];
    }
  }
  return nil;
}

- (nullable NSIndexPath *)lastIndexPathInTableView
{
  NSInteger lastSectionWithAnyRows = _tableView.numberOfSections;
  NSInteger rowCount = 0;
  while (rowCount == 0) {
    lastSectionWithAnyRows -= 1;
    if (lastSectionWithAnyRows < 0) {
      return nil;
    }
    rowCount = [_tableView numberOfRowsInSection:lastSectionWithAnyRows];
  }
  return [NSIndexPath indexPathForRow:rowCount - 1 inSection:lastSectionWithAnyRows];
}

// Same as valueForKeyPath:@"@min.self" but faster
+ (nullable id)fastArrayMin:(NSArray *)array ASDISPLAYNODE_CONST
{
  id min = nil;
  for (id obj in array) {
    if (min == nil || [obj compare:min] == NSOrderedAscending) {
      min = obj;
    }
  }
  return min;
}

// Same as valueForKeyPath:@"@max.self" but faster
+ (nullable id)fastArrayMax:(NSArray *)array ASDISPLAYNODE_CONST
{
  id max = nil;
  for (id obj in array) {
    if (max == nil || [max compare:obj] == NSOrderedAscending) {
      max = obj;
    }
  }
  return max;
}

+ (CGRect)initialSearchRectDownward:(BOOL)downward targetY:(CGFloat)targetY ASDISPLAYNODE_CONST
{
  static CGFloat const kInitialRowSearchHeight = 100;
  CGRect result = CGRectMake(0, targetY, 1, kInitialRowSearchHeight);
  if (!downward) {
    result.origin.y -= result.size.height;
  }
  return result;
}

+ (CGRect)growSearchRect:(CGRect)searchRect downward:(BOOL)downward ASDISPLAYNODE_CONST
{
  CGRect result = searchRect;
  if (!downward) {
    result.origin.y -= result.size.height;
  }
  result.size.height *= 2;
  return result;
}

@end
