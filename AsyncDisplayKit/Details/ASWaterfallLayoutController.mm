/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASWaterfallLayoutController.h"

#include <map>
#include <vector>
#include <cassert>

#import "ASAssert.h"

static const CGFloat kASWaterfallLayoutControllerRefreshingThreshold = 0.3;

@interface ASWaterfallLayoutController() {
  std::vector<std::vector<CGRect> > _nodeRects;
  std::vector<std::vector<CGRect> > _rectIndexs;
  long _indexSize;
  std::vector<std::vector<CGFloat> > _lastColumnBottom;

  std::pair<int, int> _visibleRangeStartPos;
  std::pair<int, int> _visibleRangeEndPos;

  std::vector<std::pair<int, int>> _rangeStartPos;
  std::vector<std::pair<int, int>> _rangeEndPos;

  std::vector<ASRangeTuningParameters> _tuningParameters;
}

@end

@implementation ASWaterfallLayoutController

- (instancetype)init {
  if (!(self = [super init])) {
    return nil;
  }


  _tuningParameters = std::vector<ASRangeTuningParameters>(ASLayoutRangeTypeCount);
  _tuningParameters[ASLayoutRangeTypePreload] = {
    .leadingBufferScreenfuls = 2,
    .trailingBufferScreenfuls = 1
  };
  _tuningParameters[ASLayoutRangeTypeRender] = {
    .leadingBufferScreenfuls = 3,
    .trailingBufferScreenfuls = 2
  };
    
    _indexSize = 5;
    _columnCount = 2;
    _itemRenderDirection = ASCollectionViewWaterfallLayoutItemRenderDirectionRightToLeft;//ASCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst;//ASCollectionViewWaterfallLayoutItemRenderDirectionLeftToRight;
    
    ASWaterfallLayoutDirection direction = (((UICollectionViewFlowLayout *)self).scrollDirection == UICollectionViewScrollDirectionHorizontal) ? ASWaterfallLayoutDirectionHorizontal : ASWaterfallLayoutDirectionVertical;
    _layoutDirection = direction;

  return self;
}

- (CGSize)collectionViewContentSize {
    NSInteger numberOfSections = [self.collectionView numberOfSections];
    if (numberOfSections == 0) {
        return CGSizeZero;
    }
    
    CGSize contentSize = self.collectionView.bounds.size;
    if (_nodeRects.size()>0) {
        std::vector<CGRect> &v = _nodeRects[_nodeRects.size()-1];
        if (v.size()>0) {
            CGFloat maxY = CGRectGetMaxY(v[v.size()-1]);
            if (v.size()>1) {
                maxY = MAX(maxY, CGRectGetMaxY(v[v.size()-2]));
            }
            contentSize.height = maxY;
        }
    }
    
    return contentSize;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section >= _nodeRects.size()) {
        return nil;
    }
    if (indexPath.item >= _nodeRects[indexPath.section].size()) {
        return nil;
    }
    UICollectionViewLayoutAttributes *attribute = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attribute.frame = _nodeRects[indexPath.section][indexPath.item];
    
    return attribute;
}

-(NSArray *)layoutAttributesForElementsInRect:(CGRect)rect{
    NSMutableArray *attrs = [NSMutableArray array];
    size_t beginS=0, beginI=0, endS=0, endI=0;
    for(size_t i=0;i<_rectIndexs.size();i++){
        BOOL found = NO;
        for(int j=0;j<_rectIndexs[i].size();j++)
        if (CGRectIntersectsRect(rect, _rectIndexs[i][j])){
            beginS = i;
            beginI = MAX(j * _indexSize,0);
            found = YES;
            break;
        }
        if (found) {
            break;
        }
    }
    
    for(long i=(long)(_rectIndexs.size()-1);i>=0;i--){
        BOOL found = NO;
        for(long j=(long)(_rectIndexs[i].size()-1);j>=0;j--)
            if (CGRectIntersectsRect(rect, _rectIndexs[i][j])){
                endS = i;
                endI = MIN((j + 1) * _indexSize, _nodeRects[i].size());
                found = YES;
                break;
            }
        if (found) {
            break;
        }
    }
    
    size_t j = beginI;
    for (size_t i = beginS; i<endS; i++) {
        while (j<_nodeRects[i].size()) {
            UICollectionViewLayoutAttributes *attr = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:j inSection:i]];
            attr.frame = _nodeRects[i][j];
            [attrs addObject:attr];
            j++;
        }
        j = 0;
    }
    
    while (j<endI) {
        UICollectionViewLayoutAttributes *attr = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:[NSIndexPath indexPathForItem:j inSection:endS]];
        attr.frame = _nodeRects[endS][j];
        [attrs addObject:attr];
        j++;
    }
    
    return [NSArray arrayWithArray:attrs];
}

-(BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds{
    CGRect oldBounds = self.collectionView.bounds;
    if (CGRectGetWidth(newBounds) != CGRectGetWidth(oldBounds)) {
        return YES;
    }
    return NO;
}

- (NSInteger)columnCountForSection:(NSInteger)section {
    return _columnCount;
}

- (NSUInteger)nextColumnIndexForItem:(NSInteger)item inSection:(NSInteger)section {
    NSUInteger index = 0;
    NSInteger columnCount = [self columnCountForSection:section];
    switch (self.itemRenderDirection) {
        case ASCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst:
            index = [self shortestColumnIndexInSection:section];
            break;
            
        case ASCollectionViewWaterfallLayoutItemRenderDirectionLeftToRight:
            index = (item % columnCount);
            break;
            
        case ASCollectionViewWaterfallLayoutItemRenderDirectionRightToLeft:
            index = (columnCount - 1) - (item % columnCount);
            break;
            
        default:
            index = [self shortestColumnIndexInSection:section];
            break;
    }
    return index;
}

-(int) findColumnTopAtSection:(long) section atIndex:(long) idx{
    CGFloat top = 0;
    if (_itemRenderDirection==ASCollectionViewWaterfallLayoutItemRenderDirectionShortestFirst) {
        NSUInteger mycolIdx = [self nextColumnIndexForItem:idx inSection:section];
        top = _lastColumnBottom[section][mycolIdx];
    }else{
        long j = idx-[self columnCountForSection:section];
        long i = section;
        while (i>=0) {
            if (i<_nodeRects.size() && j>=0 && j<_nodeRects[i].size()) {
                top = CGRectGetMaxY(_nodeRects[i][j]);
                break;
            }else if(i>=_nodeRects.size() || j>=_nodeRects[i].size()){
                break;
            }else{
                i--;//last section
                j = _nodeRects[i].size()-1;
            }
        }
    }
    
    return top;
}

/**
 *  Find the shortest column.
 *
 *  @return index for the shortest column
 */
- (NSUInteger)shortestColumnIndexInSection:(NSInteger)section {
    NSUInteger index = 0;
    CGFloat shortestHeight = MAXFLOAT;
    
    if (section>=_lastColumnBottom.size()) {
        return 0;
    }
    
    std::vector<CGFloat> &cb = _lastColumnBottom[section];
    for (int i=0; i<cb.size(); i++) {
        if (cb[i] < shortestHeight) {
            shortestHeight = cb[i];
            index = i;
        }
    }
    
    
    return index;
}

/**
 *  Find the longest column.
 *
 *  @return index for the longest column
 */
- (NSUInteger)longestColumnIndexInSection:(NSInteger)section {
    NSUInteger index = 0;
    CGFloat longestHeight = 0;
    
    if (section>=_lastColumnBottom.size()) {
        return 0;
    }
    
    std::vector<CGFloat> &cb = _lastColumnBottom[section];
    for (int i=0; i<cb.size(); i++) {
        if (cb[i] > longestHeight) {
            longestHeight = cb[i];
            index = i;
        }
    }
    
    return index;
}

#pragma mark - Tuning Parameters

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeType] = tuningParameters;
}

// Support for the deprecated tuningParameters property
- (ASRangeTuningParameters)tuningParameters
{
  return [self tuningParametersForRangeType:ASLayoutRangeTypeRender];
}

// Support for the deprecated tuningParameters property
- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  [self setTuningParameters:tuningParameters forRangeType:ASLayoutRangeTypeRender];
}

#pragma mark - Editing

- (void)insertNodesAtIndexPaths:(NSArray *)indexPaths withSizes:(NSArray *)nodeSizes
{
  ASDisplayNodeAssert(indexPaths.count == nodeSizes.count, @"Inconsistent index paths and node size");
 
    __block long minIdx = LONG_MAX;
    __block long minSec = LONG_MAX;
  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
      CGSize itemSize = [(NSValue *)nodeSizes[idx] CGSizeValue];
      
      minIdx = MIN(minIdx,indexPath.row);
      minSec = MIN(minSec,indexPath.section);
      
      CGFloat itemWidth = itemSize.width;
      CGFloat itemHeight = itemSize.height;
      CGRect myrect = CGRectMake(0, 0, itemWidth, itemHeight);
      std::vector<CGRect> &v = _nodeRects[indexPath.section];
      v.insert(v.begin() + indexPath.row, myrect);
    }];
    
    //update others
    size_t i=minSec;
    size_t j=minIdx;
    CGFloat bottom = 0;
    for(;i<_nodeRects.size();i++){
        for (int col=0;col<_lastColumnBottom[i].size(); col++) {
            _lastColumnBottom[i][col] = bottom;
        }
        
        for ( ;j<_nodeRects[i].size(); j++) {
            NSUInteger mycolIdx = [self nextColumnIndexForItem:j inSection:i];
            CGFloat itemWidth = _nodeRects[i][j].size.width;
            CGFloat myx = itemWidth * mycolIdx;
            CGFloat myy = [self findColumnTopAtSection:i atIndex:j];//
            _nodeRects[i][j].origin.x = myx; _nodeRects[i][j].origin.y = myy;
            _lastColumnBottom[i][mycolIdx] = CGRectGetMaxY(_nodeRects[i][j]);
        }
        
        NSUInteger longestColIdx = [self longestColumnIndexInSection:i];
        bottom = _lastColumnBottom[i][longestColIdx];
        j = 0;
    }
    
    size_t curj = (minIdx/_indexSize)*_indexSize;
    size_t curi = minSec;
    
    for(;curi<_nodeRects.size();curi++){
        while(curj<_nodeRects[curi].size()){
            size_t end = MIN(curj + _indexSize, _nodeRects[curi].size());
            CGRect rectIndex = _nodeRects[curi][curj];
            for (size_t j=curj+1; j<end; j++) {
                rectIndex = CGRectUnion(rectIndex, _nodeRects[curi][j]);
            }
            size_t curIdx = curj/_indexSize;
            if(curIdx<_rectIndexs[curi].size()){
                _rectIndexs[curi][curIdx] = rectIndex;
            }else{
                _rectIndexs[curi].push_back(rectIndex);
            }
            
            curj = end;
        }
        curj = 0;
    }
}

- (void)deleteNodesAtIndexPaths:(NSArray *)indexPaths
{
    __block long minIdx = LONG_MAX;
    __block long minSec = LONG_MAX;
  [indexPaths enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    std::vector<CGRect> &v = _nodeRects[indexPath.section];
    v.erase(v.begin() + indexPath.row);
      
      minIdx = MIN(minIdx,indexPath.row);
      minSec = MIN(minSec,indexPath.section);
  }];
    
    //update others
    size_t j=minIdx;
    for(size_t i=minSec;i<_nodeRects.size();i++){
        for ( ;j<_nodeRects[i].size(); j++) {
            NSUInteger mycolIdx = [self nextColumnIndexForItem:j inSection:i];
            CGFloat itemWidth = _nodeRects[i][j].size.width;
            CGFloat myx = itemWidth * mycolIdx;
            CGFloat myy = [self findColumnTopAtSection:i atIndex:j];//ASFindNodeTop(_nodeRects, i, j, [self columnCountForSection:i]);
            _nodeRects[i][j].origin.x = myx; _nodeRects[i][j].origin.y = myy;
            _lastColumnBottom[i][mycolIdx] = CGRectGetMaxY(_nodeRects[i][j]);
        }
        j = 0;
    }
    
    size_t curj = (minIdx/_indexSize)*_indexSize;
    size_t curi = minSec;
    
    for(;curi<_nodeRects.size();curi++){
        while(curj<_nodeRects[curi].size()){
            size_t end = MIN(curj + _indexSize, _nodeRects[curi].size());
            CGRect rectIndex = _nodeRects[curi][curj];
            for (size_t j=curj+1; j<end; j++) {
                rectIndex = CGRectUnion(rectIndex, _nodeRects[curi][j]);
            }
            size_t curIdx = curj/_indexSize;
            if(curIdx<_rectIndexs[curi].size()){
                _rectIndexs[curi][curIdx].origin.x = rectIndex.origin.x;
                _rectIndexs[curi][curIdx].origin.y = rectIndex.origin.y;
                _rectIndexs[curi][curIdx].size.width = rectIndex.size.width;
                _rectIndexs[curi][curIdx].size.height = rectIndex.size.height;
            }else{
                _rectIndexs[curi].push_back(rectIndex);
            }
            
            curj = end;
        }
        curj = 0;
    }
}

- (void)insertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet
{
  __block int cnt = 0;
  [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
    NSArray *nodes = sections[cnt++];//why not idx?
    std::vector<CGRect> v;
    v.reserve(nodes.count);
      std::vector<CGRect> iv;
      iv.reserve((nodes.count+_indexSize-1)/_indexSize);
      
      long colCount = [self columnCountForSection:idx];
      std::vector<CGFloat> bv;
      bv.reserve(colCount);
      for (int i=0;i<colCount; i++) {
          bv.push_back(0);
      }
      
      for (int i = 0; i < nodes.count; i++) {
          CGSize itemSize = [(NSValue *)nodes[i] CGSizeValue];
          
          NSUInteger columnIndex = [self nextColumnIndexForItem:i inSection:idx];
          CGFloat itemWidth = itemSize.width;
          CGFloat xOffset = itemWidth * columnIndex;
          CGFloat yOffset = [self findColumnTopAtSection:idx atIndex:i];//ASFindNodeTop(_nodeRects, idx, i, colCount);
          CGRect myrect = CGRectMake(xOffset, yOffset, itemSize.width, itemSize.height);
          
          v.insert(v.begin() + i, myrect);
              
          //update rect index
          size_t indexI = i/_indexSize;
          
          if (iv.size()<=indexI) {
              iv.push_back(myrect);
          }else{
              iv[indexI] = CGRectUnion(iv[indexI], myrect);
          }
      }

    _nodeRects.insert(_nodeRects.begin() + idx, v);
      _rectIndexs.insert(_rectIndexs.begin()+idx, iv);
      _lastColumnBottom.insert(_lastColumnBottom.begin()+idx, bv);
    
  }];
}

- (void)deleteSectionsAtIndexSet:(NSIndexSet *)indexSet {
  [indexSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop)
  {
    _nodeRects.erase(_nodeRects.begin() +idx);
      _rectIndexs.erase(_rectIndexs.begin()+idx);
  }];
}

#pragma mark - Visible Indices

- (BOOL)shouldUpdateForVisibleIndexPaths:(NSArray *)indexPaths viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  if (!indexPaths.count) {
    return NO;
  }

  std::pair<int, int> rangeStartPos, rangeEndPos;

  if (rangeType < _rangeStartPos.size() && rangeType < _rangeEndPos.size()) {
    rangeStartPos = _rangeStartPos[rangeType];
    rangeEndPos = _rangeEndPos[rangeType];
  }

  std::pair<int, int> startPos, endPos;
  ASFindIndexPathRange(indexPaths, startPos, endPos);

  if (rangeStartPos >= startPos || rangeEndPos <= endPos) {
    return YES;
  }

  return ASWaterfallLayoutDistance(startPos, _visibleRangeStartPos, _nodeRects) > ASWaterfallLayoutDistance(_visibleRangeStartPos, rangeStartPos, _nodeRects) * kASWaterfallLayoutControllerRefreshingThreshold ||
  ASWaterfallLayoutDistance(endPos, _visibleRangeEndPos, _nodeRects) > ASWaterfallLayoutDistance(_visibleRangeEndPos, rangeEndPos, _nodeRects) * kASWaterfallLayoutControllerRefreshingThreshold;
}

- (BOOL)shouldUpdateForVisibleIndexPath:(NSArray *)indexPaths
                                        viewportSize:(CGSize)viewportSize
{
  return [self shouldUpdateForVisibleIndexPaths:indexPaths viewportSize:viewportSize rangeType:ASLayoutRangeTypeRender];
}

- (void)setVisibleNodeIndexPaths:(NSArray *)indexPaths
{
  ASFindIndexPathRange(indexPaths, _visibleRangeStartPos, _visibleRangeEndPos);
}

/**
 * IndexPath array for the element in the working range.
 */

- (NSSet *)indexPathsForScrolling:(enum ASScrollDirection)scrollDirection viewportSize:(CGSize)viewportSize rangeType:(ASLayoutRangeType)rangeType
{
  CGFloat viewportScreenMetric;
  ASScrollDirection leadingDirection;

  if (_layoutDirection == ASWaterfallLayoutDirectionHorizontal) {
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

  std::pair<int, int> startIter = ASFindIndexForRange(_nodeRects, _visibleRangeStartPos, - backScreens * viewportScreenMetric, _layoutDirection);
  std::pair<int, int> endIter = ASFindIndexForRange(_nodeRects, _visibleRangeEndPos, frontScreens * viewportScreenMetric, _layoutDirection);

  NSMutableSet *indexPathSet = [[NSMutableSet alloc] init];

  while (startIter != endIter) {
    [indexPathSet addObject:[NSIndexPath indexPathForRow:startIter.second inSection:startIter.first]];
    startIter.second++;

    while (startIter.second == _nodeRects[startIter.first].size() && startIter.first < _nodeRects.size()) {
      startIter.second = 0;
      startIter.first++;
    }
  }

  [indexPathSet addObject:[NSIndexPath indexPathForRow:endIter.second inSection:endIter.first]];
  
  return indexPathSet;
}

- (NSSet *)indexPathsForScrolling:(enum ASScrollDirection)scrollDirection
                                 viewportSize:(CGSize)viewportSize
{
  return [self indexPathsForScrolling:scrollDirection viewportSize:viewportSize rangeType:ASLayoutRangeTypeRender];
}

#pragma mark - Utility

static void ASFindIndexPathRange(NSArray *indexPaths, std::pair<int, int> &startPos, std::pair<int, int> &endPos)

{
  NSIndexPath *initialIndexPath = [indexPaths firstObject];
  startPos = endPos = {initialIndexPath.section, initialIndexPath.row};
  [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
    std::pair<int, int> p(indexPath.section, indexPath.row);
    startPos = MIN(startPos, p);
    endPos = MAX(endPos, p);
  }];
}

static const std::pair<int, int> ASFindIndexForRange(const std::vector<std::vector<CGRect>> &nodes,
                                                     const std::pair<int, int> &pos,
                                                     CGFloat range,
                                                     ASWaterfallLayoutDirection layoutDirection)
{
  std::pair<int, int> cur = pos, pre = pos;

  if (range < 0.0 && cur.first >= 0 && cur.first < nodes.size() && cur.second >= 0 && cur.second < nodes[cur.first].size()) {
    // search backward
    while (range < 0.0 && cur.first >= 0 && cur.second >= 0) {
      pre = cur;
      CGSize size = nodes[cur.first][cur.second].size;
      range += layoutDirection == ASWaterfallLayoutDirectionHorizontal ? size.width : size.height;
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
      CGSize size = nodes[cur.first][cur.second].size;
      range -= layoutDirection == ASWaterfallLayoutDirectionHorizontal ? size.width : size.height;

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

static int ASWaterfallLayoutDistance(const std::pair<int, int> &start, const std::pair<int, int> &end, const std::vector<std::vector<CGRect>> &nodes)
{
  if (start == end) {
    return 0;
  } else if (start > end) {
    return - ASWaterfallLayoutDistance(end, start, nodes);
  }

  int res = 0;

  for (int i = start.first; i <= end.first; i++) {
    res += (i == end.first ? end.second + 1 : nodes[i].size()) - (i == start.first ? start.second : 0);
  }

  return res;
}

@end
