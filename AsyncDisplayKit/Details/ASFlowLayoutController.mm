//
//  ASFlowLayoutController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASFlowLayoutController.h"
#import "ASAssert.h"
#import "ASDisplayNode.h"
#import "ASIndexPath.h"
#import "CGRect+ASConvenience.h"

#include <map>
#include <vector>

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

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths
{
  _visibleRange = [self indexPathRangeForIndexPaths:indexPaths];
}

/**
 * IndexPath array for the element in the working range.
 */

- (NSSet *)indexPathsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  CGSize viewportSize = [self viewportSize];

  CGFloat viewportDirectionalSize = 0.0;
  ASDirectionalScreenfulBuffer directionalBuffer = { 0, 0 };
  ASRangeTuningParameters      tuningParameters  = [self tuningParametersForRangeMode:rangeMode rangeType:rangeType];

  if (_layoutDirection == ASFlowLayoutDirectionHorizontal) {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone ||
                        scrollDirection == ASScrollDirectionLeft ||
                        scrollDirection == ASScrollDirectionRight, @"Invalid scroll direction");

    viewportDirectionalSize = viewportSize.width;
    directionalBuffer = ASDirectionalScreenfulBufferHorizontal(scrollDirection, tuningParameters);
  } else {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone ||
                        scrollDirection == ASScrollDirectionUp   ||
                        scrollDirection == ASScrollDirectionDown, @"Invalid scroll direction");

    viewportDirectionalSize = viewportSize.height;
    directionalBuffer = ASDirectionalScreenfulBufferVertical(scrollDirection, tuningParameters);
  }
  
  ASIndexPath startPath = [self findIndexPathAtDistance:(-directionalBuffer.negativeDirection * viewportDirectionalSize)
                                          fromIndexPath:_visibleRange.start];
  
  ASIndexPath endPath   = [self findIndexPathAtDistance:(directionalBuffer.positiveDirection * viewportDirectionalSize)
                                          fromIndexPath:_visibleRange.end];

  ASDisplayNodeAssert(startPath.section <= endPath.section, @"startPath should never begin at a further position than endPath");
  
  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];

  NSArray *completedNodes = [_dataSource completedNodes];

  ASIndexPath currPath = startPath;
  
  while (!ASIndexPathEqualToIndexPath(currPath, endPath)) {
    [indexPathSet addObject:[NSIndexPath indexPathWithASIndexPath:currPath]];
    currPath.row++;

    // Once we reach the end of the section, advance to the next one.  Keep advancing if the next section is zero-sized.
    while (currPath.row >= [(NSArray *)completedNodes[currPath.section] count] && currPath.section < endPath.section) {
      currPath.row = 0;
      currPath.section++;
    }
  }
  ASDisplayNodeAssert(currPath.section <= endPath.section, @"currPath should never reach a further section than endPath");

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
