/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASFlowLayoutController.h"
#import "ASAssert.h"
#import "ASDisplayNode.h"
#import "ASIndexPath.h"

#include <map>
#include <vector>
#include <cassert>

static const CGFloat kASFlowLayoutControllerRefreshingThreshold = 0.3;

@interface ASFlowLayoutController()
{
  ASIndexPathRange _visibleRange;
  std::vector<ASIndexPathRange> _rangesByType;  // All ASLayoutRangeTypes besides visible.
}

@end

@implementation ASFlowLayoutController

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection
{
  if (!(self = [super init])) {
    return nil;
  }
  _layoutDirection = layoutDirection;
  _rangesByType = std::vector<ASIndexPathRange>(ASLayoutRangeTypeCount);
  return self;
}

#pragma mark - Visible Indices

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  if (!indexPaths.count || rangeType >= _rangesByType.size()) {
    return NO;
  }

  ASIndexPathRange existingRange = _rangesByType[rangeType];
  ASIndexPathRange newRange = [self indexPathRangeForIndexPaths:indexPaths];
  
  ASIndexPath maximumStart = ASIndexPathMaximum(existingRange.start, newRange.start);
  ASIndexPath minimumEnd = ASIndexPathMinimum(existingRange.end, newRange.end);
  
  if (ASIndexPathEqualToIndexPath(maximumStart, existingRange.start) || ASIndexPathEqualToIndexPath(minimumEnd, existingRange.end)) {
    return YES;
  }

  NSInteger newStartDelta       = [self flowLayoutDistanceForRange:ASIndexPathRangeMake(_visibleRange.start, newRange.start)];
  NSInteger existingStartDelta  = [self flowLayoutDistanceForRange:ASIndexPathRangeMake(_visibleRange.start, existingRange.start)] * kASFlowLayoutControllerRefreshingThreshold;
  
  NSInteger newEndDelta         = [self flowLayoutDistanceForRange:ASIndexPathRangeMake(_visibleRange.end, newRange.end)];
  NSInteger existingEndDelta    = [self flowLayoutDistanceForRange:ASIndexPathRangeMake(_visibleRange.end, existingRange.end)] * kASFlowLayoutControllerRefreshingThreshold;
  
  return (newStartDelta > existingStartDelta) || (newEndDelta > existingEndDelta);
}

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths
{
  _visibleRange = [self indexPathRangeForIndexPaths:indexPaths];
}

/**
 * IndexPath array for the element in the working range.
 */

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  CGFloat viewportScreenMetric;
  ASScrollDirection leadingDirection;

  if (_layoutDirection == ASFlowLayoutDirectionHorizontal) {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone || scrollDirection == ASScrollDirectionLeft || scrollDirection == ASScrollDirectionRight, @"Invalid scroll direction");

    viewportScreenMetric = viewportSize.width;
    leadingDirection = ASScrollDirectionLeft;
  } else {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone || scrollDirection == ASScrollDirectionUp || scrollDirection == ASScrollDirectionDown, @"Invalid scroll direction");

    viewportScreenMetric = viewportSize.height;
    leadingDirection = ASScrollDirectionUp;
  }

  ASRangeTuningParameters tuningParameters = [self tuningParametersForRangeType:rangeType];
  CGFloat backScreens = scrollDirection == leadingDirection ? tuningParameters.leadingBufferScreenfuls : tuningParameters.trailingBufferScreenfuls;
  CGFloat frontScreens = scrollDirection == leadingDirection ? tuningParameters.trailingBufferScreenfuls : tuningParameters.leadingBufferScreenfuls;

  
  ASIndexPath startPath = [self findIndexPathAtDistance:(-backScreens * viewportScreenMetric) fromIndexPath:_visibleRange.start];
  ASIndexPath endPath = [self findIndexPathAtDistance:(frontScreens * viewportScreenMetric) fromIndexPath:_visibleRange.end];

  ASDisplayNodeAssert(startPath.section <= endPath.section, @"startPath should never begin at a further position than endPath");
  
  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];

  NSArray *completedNodes = [_dataSource completedNodes];
  
  while (!ASIndexPathEqualToIndexPath(startPath, endPath)) {
    [indexPathSet addObject:[NSIndexPath indexPathWithASIndexPath:startPath]];
    startPath.row++;

    // Once we reach the end of the section, advance to the next one.  Keep advancing if the next section is zero-sized.
    while (startPath.row >= [(NSArray *)completedNodes[startPath.section] count] && startPath.section < completedNodes.count - 1) {
      startPath.row = 0;
      startPath.section++;
      ASDisplayNodeAssert(startPath.section <= endPath.section, @"startPath should never reach a further section than endPath");
    }
  }

  [indexPathSet addObject:[NSIndexPath indexPathWithASIndexPath:endPath]];
  
  return indexPathSet;
}

#pragma mark - Utility

- (ASIndexPathRange)indexPathRangeForIndexPaths:(NSArray *)indexPaths
{
  // Set up an initial value so the MIN and MAX can work in the enumeration.
  __block ASIndexPath currentIndexPath = [[indexPaths firstObject] ASIndexPathValue];
  __block ASIndexPathRange range;
  range.start = currentIndexPath;
  range.end = currentIndexPath;
  
  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    currentIndexPath = [indexPath ASIndexPathValue];
    range.start = ASIndexPathMinimum(range.start, currentIndexPath);
    range.end = ASIndexPathMaximum(range.end, currentIndexPath);
  }];
  return range;
}

- (ASIndexPath)findIndexPathAtDistance:(CGFloat)distance fromIndexPath:(ASIndexPath)start
{
  // "end" is the index path we'll advance until we have gone far enough from "start" to reach "distance"
  ASIndexPath end = start;
  // "previous" will store one iteration before "end", in case we go too far and need to reset "end" to be "previous"
  ASIndexPath previous = start;

  NSArray *completedNodes = [_dataSource completedNodes];
  NSUInteger numberOfSections = [completedNodes count];
  NSUInteger numberOfRowsInSection = [(NSArray *)completedNodes[end.section] count];
  
  // If "distance" is negative, advance "end" backwards across rows and sections.
  // Otherwise, advance forward.  In either case, bring "distance" closer to zero by the dimension of each row passed.
  if (distance < 0.0 && end.section >= 0 && end.section < numberOfSections && end.row >= 0 && end.row < numberOfRowsInSection) {
    while (distance < 0.0 && end.section >= 0 && end.row >= 0) {
      previous = end;
      ASDisplayNode *node = completedNodes[end.section][end.row];
      CGSize size = node.calculatedSize;
      distance += (_layoutDirection == ASFlowLayoutDirectionHorizontal ? size.width : size.height);
      end.row--;
      // If we've gone to a negative row, set to the last row of the previous section.  While loop is required to handle empty sections.
      while (end.row < 0 && end.section > 0) {
        end.section--;
        numberOfRowsInSection = [(NSArray *)completedNodes[end.section] count];
        end.row = numberOfRowsInSection - 1;
      }
    }

    if (end.row < 0) {
      end = previous;
    }
  } else {
    while (distance > 0.0 && end.section >= 0 && end.section < numberOfSections && end.row >= 0 && end.row < numberOfRowsInSection) {
      previous = end;
      ASDisplayNode *node = completedNodes[end.section][end.row];
      CGSize size = node.calculatedSize;
      distance -= _layoutDirection == ASFlowLayoutDirectionHorizontal ? size.width : size.height;

      end.row++;
      // If we've gone beyond the section, reset to the beginning of the next section.  While loop is required to handle empty sections.
      while (end.row >= numberOfRowsInSection && end.section < numberOfSections - 1) {
        end.row = 0;
        end.section++;
        numberOfRowsInSection = [(NSArray *)completedNodes[end.section] count];
      }
    }

    if (end.row >= numberOfRowsInSection) {
      end = previous;
    }
  }

  return end;
}

- (NSInteger)flowLayoutDistanceForRange:(ASIndexPathRange)range
{
  // This method should only be called with the range in proper order (start comes before end).
  ASDisplayNodeAssert(ASIndexPathEqualToIndexPath(ASIndexPathMinimum(range.start, range.end), range.start), @"flowLayoutDistanceForRange: called with invalid range");
  
  if (ASIndexPathEqualToIndexPath(range.start, range.end)) {
    return 0;
  }
  
  NSInteger totalRowCount = 0;
  NSUInteger numberOfRowsInSection = 0;
  NSArray *completedNodes = [_dataSource completedNodes];

  for (NSInteger section = range.start.section; section <= range.end.section; section++) {
    numberOfRowsInSection = [(NSArray *)completedNodes[section] count];
    totalRowCount += numberOfRowsInSection;
    
    if (section == range.start.section) {
      // For the start section, make sure we don't count the rows before the start row.
      totalRowCount -= range.start.row;
    } else if (section == range.end.section) {
      // For the start section, make sure we don't count the rows after the end row.
      totalRowCount -= (numberOfRowsInSection - (range.end.row + 1));
    }
  }
  
  ASDisplayNodeAssert(totalRowCount >= 0, @"totalRowCount in flowLayoutDistanceForRange: should not be negative");
  return totalRowCount;
}

@end
