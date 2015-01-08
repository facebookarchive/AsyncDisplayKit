//  Copyright 2004-present Facebook. All Rights Reserved.

#import "ASFlowLayoutController.h"

#include <map>
#include <vector>
#include <cassert>

#import "ASAssert.h"

static const CGFloat kASFlowLayoutControllerRefreshingThreshold = 0.3;

@interface ASFlowLayoutController() {
  std::vector<std::vector<CGSize> > _nodeSizes;

  std::pair<int, int> _visibleRangeStartPos;
  std::pair<int, int> _visibleRangeEndPos;

  std::pair<int, int> _workingRangeStartPos;
  std::pair<int, int> _workingRangeEndPos;
}

@end

@implementation ASFlowLayoutController

- (instancetype)initWithScrollOption:(ASFlowLayoutDirection)layoutDirection {
  if (!(self = [super init])) {
    return nil;
  }

  _layoutDirection = layoutDirection;

  _tuningParameters.leadingBufferScreenfuls = 2;
  _tuningParameters.trailingBufferScreenfuls = 1;

  return self;
}

- (void)insertNodesAtIndexPaths:(NSArray *)indexPaths withSizes:(NSArray *)nodeSizes {
  ASDisplayNodeAssert(indexPaths.count == nodeSizes.count, @"Inconsistent index paths and node size");

  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    std::vector<CGSize> &v = _nodeSizes[indexPath.section];
    v.insert(v.begin() + indexPath.row, [(NSValue *)nodeSizes[idx] CGSizeValue]);
  }];
}

- (void)deleteNodesAtIndexPaths:(NSArray *)indexPaths {
  [indexPaths enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    std::vector<CGSize> &v = _nodeSizes[indexPath.section];
    v.erase(v.begin() + indexPath.row);
  }];
}

- (void)insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet {
  __block int cnt = 0;
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSArray *nodes = sections[cnt++];
    std::vector<CGSize> v;
    v.reserve(nodes.count);

    for (int i = 0; i < nodes.count; i++) {
      v.push_back([nodes[i] CGSizeValue]);
    }

    _nodeSizes.insert(_nodeSizes.begin() + idx, v);
  }];
}

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet {
  [indexSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
    _nodeSizes.erase(_nodeSizes.begin() +idx);
  }];
}

- (BOOL)shouldUpdateWorkingRangesForVisibleIndexPath:(NSArray *)indexPaths
                                        viewportSize:(CGSize)viewportSize {
  if (!indexPaths.count) {
    return NO;
  }

  std::pair<int, int> startPos, endPos;
  ASFindIndexPathRange(indexPaths, startPos, endPos);

  if (_workingRangeStartPos >= startPos || _workingRangeEndPos <= endPos) {
    return YES;
  }

  return ASFlowLayoutDistance(startPos, _visibleRangeStartPos, _nodeSizes) > ASFlowLayoutDistance(_visibleRangeStartPos, _workingRangeStartPos, _nodeSizes) * kASFlowLayoutControllerRefreshingThreshold ||
         ASFlowLayoutDistance(endPos, _visibleRangeEndPos, _nodeSizes) > ASFlowLayoutDistance(_visibleRangeEndPos, _workingRangeEndPos, _nodeSizes) * kASFlowLayoutControllerRefreshingThreshold;
}

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths {
  ASFindIndexPathRange(indexPaths, _visibleRangeStartPos, _visibleRangeEndPos);
}

/**
 * IndexPath array for the element in the working range.
 */
- (NSSet *)workingRangeIndexPathsForScrolling:(enum ASScrollDirection)scrollDirection
                                 viewportSize:(CGSize)viewportSize {
  std::pair<int, int> startIter, endIter;

  if (_layoutDirection == ASFlowLayoutDirectionHorizontal) {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone || scrollDirection == ASScrollDirectionLeft || scrollDirection == ASScrollDirectionRight, @"Invalid scroll direction");

    CGFloat backScreens = scrollDirection == ASScrollDirectionLeft ? self.tuningParameters.leadingBufferScreenfuls : self.tuningParameters.trailingBufferScreenfuls;
    CGFloat frontScreens = scrollDirection == ASScrollDirectionLeft ? self.tuningParameters.trailingBufferScreenfuls : self.tuningParameters.leadingBufferScreenfuls;

    startIter = ASFindIndexForRange(_nodeSizes, _visibleRangeStartPos, - backScreens * viewportSize.width, _layoutDirection);
    endIter = ASFindIndexForRange(_nodeSizes, _visibleRangeEndPos, frontScreens * viewportSize.width, _layoutDirection);
  } else {
    ASDisplayNodeAssert(scrollDirection == ASScrollDirectionNone || scrollDirection == ASScrollDirectionUp || scrollDirection == ASScrollDirectionDown, @"Invalid scroll direction");

    int backScreens = scrollDirection == ASScrollDirectionUp ? self.tuningParameters.leadingBufferScreenfuls : self.tuningParameters.trailingBufferScreenfuls;
    int frontScreens = scrollDirection == ASScrollDirectionUp ? self.tuningParameters.trailingBufferScreenfuls : self.tuningParameters.leadingBufferScreenfuls;

    startIter = ASFindIndexForRange(_nodeSizes, _visibleRangeStartPos, - backScreens * viewportSize.height, _layoutDirection);
    endIter = ASFindIndexForRange(_nodeSizes, _visibleRangeEndPos, frontScreens * viewportSize.height, _layoutDirection);
  }

  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];

  while (startIter != endIter) {
    [indexPathSet addObject:[NSIndexPath indexPathForRow:startIter.second inSection:startIter.first]];
    startIter.second++;

    while (startIter.second == _nodeSizes[startIter.first].size() && startIter.first < _nodeSizes.size()) {
      startIter.second = 0;
      startIter.first++;
    }
  }

  [indexPathSet addObject:[NSIndexPath indexPathForRow:endIter.second inSection:endIter.first]];

  return indexPathSet;
}

static void ASFindIndexPathRange(NSArray *indexPaths, std::pair<int, int> &startPos, std::pair<int, int> &endPos) {
  NSIndexPath *initialIndexPath = [indexPaths firstObject];
  startPos = endPos = {initialIndexPath.section, initialIndexPath.row};
  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    std::pair<int, int> p(indexPath.section, indexPath.row);
    startPos = MIN(startPos, p);
    endPos = MAX(endPos, p);
  }];
}

static const std::pair<int, int> ASFindIndexForRange(const std::vector<std::vector<CGSize>> &nodes,
                                                     const std::pair<int, int> &pos,
                                                     CGFloat range,
                                                     ASFlowLayoutDirection layoutDirection) {
  std::pair<int, int> cur = pos, pre = pos;

  if (range < 0.0 && cur.first >= 0 && cur.first < nodes.size() && cur.second >= 0 && cur.second < nodes[cur.first].size()) {
    // search backward
    while (range < 0.0 && cur.first >= 0 && cur.second >= 0) {
      pre = cur;
      CGSize size = nodes[cur.first][cur.second];
      range += layoutDirection == ASFlowLayoutDirectionHorizontal ? size.width : size.height;
      cur.second--;
      while (cur.second < 0 && cur.first > 0) {
        cur.second = (int)nodes[--cur.first].size() - 1;
      }
    }

    if (cur.second < 0) {
      cur = pre;
    }
  } else {
    // search forward
    while (range > 0.0 && cur.first >= 0 && cur.first < nodes.size() && cur.second >= 0 && cur.second < nodes[cur.first].size()) {
      pre = cur;
      CGSize size = nodes[cur.first][cur.second];
      range -= layoutDirection == ASFlowLayoutDirectionHorizontal ? size.width : size.height;

      cur.second++;
      while (cur.second == nodes[cur.first].size() && cur.first < (int)nodes.size() - 1) {
        cur.second = 0;
        cur.first++;
      }
    }

    if (cur.second == nodes[cur.first].size()) {
      cur = pre;
    }
  }

  return cur;
}

static int ASFlowLayoutDistance(const std::pair<int, int> &start, const std::pair<int, int> &end, const std::vector<std::vector<CGSize>> &nodes) {
  if (start == end) {
    return 0;
  } else if (start > end) {
    return - ASFlowLayoutDistance(end, start, nodes);
  }

  int res = 0;

  for (int i = start.first; i <= end.first; i++) {
    res += (i == end.first ? end.second + 1 : nodes[i].size()) - (i == start.first ? start.second : 0);
  }

  return res;
}

@end
