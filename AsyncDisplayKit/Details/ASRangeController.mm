/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRangeController.h"

#import "ASAssert.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNodeInternal.h"
#import "ASRangeControllerInternal.h"

typedef NS_ENUM(NSInteger, ASScrollDirection) {
  ASScrollDirectionUp,
  ASScrollDirectionDown,
};

@interface ASRangeController () {
  // index path -> node mapping
  NSMutableDictionary *_nodes;

  // array of boxed CGSizes.  _nodeSizes.count == the number of nodes that have been sized
  // TODO optimise this, perhaps by making _nodes an array
  NSMutableArray *_nodeSizes;

  // consumer data source information
  NSArray *_sectionCounts;
  NSInteger _totalNodeCount;

  // used for global <-> section.row mapping.  _sectionOffsets[section] is the index at which the section starts
  NSArray *_sectionOffsets;

  // sized data source information
  NSInteger _sizedNodeCount;

  // ranges
  BOOL _queuedRangeUpdate;
  ASScrollDirection _scrollDirection;
  NSRange _visibleRange;
  NSRange _workingRange;
  NSMutableOrderedSet *_workingIndexPaths;
}

@end


@implementation ASRangeController

#pragma mark -
#pragma mark Lifecycle.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _tuningParameters = {
    .trailingBufferScreenfuls = 1,
    .leadingBufferScreenfuls = 2,
  };

  return self;
}

- (void)dealloc
{
  [self teardownAllNodes];
}

- (void)teardownAllNodes
{
  for (ASCellNode *node in _nodes.allValues) {
    [node removeFromSupernode];
    [node.view removeFromSuperview];
  }
  [_nodes removeAllObjects];
  _nodes = nil;

}

+ (dispatch_queue_t)sizingQueue
{
  static dispatch_queue_t sizingQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sizingQueue = dispatch_queue_create("com.facebook.AsyncDisplayKit.ASRangeController.sizingQueue", DISPATCH_QUEUE_CONCURRENT);
    // we use the highpri queue to prioritize UI rendering over other async operations
    dispatch_set_target_queue(sizingQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  });

  return sizingQueue;
}

+ (UIView *)workingView
{
  // we add nodes' views to this invisible window to start async rendering
  static UIWindow *workingWindow = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    workingWindow = [[UIWindow alloc] initWithFrame:CGRectZero];
    workingWindow.windowLevel = UIWindowLevelNormal - 1000;
    workingWindow.userInteractionEnabled = NO;
    workingWindow.clipsToBounds = YES;
    workingWindow.hidden = YES;
  });

  return workingWindow;
}


#pragma mark -
#pragma mark Helpers.

static NSOrderedSet *ASCopySetMinusSet(NSOrderedSet *minuend, NSOrderedSet *subtrahend)
{
  NSMutableOrderedSet *difference = [minuend mutableCopy];
  [difference minusOrderedSet:subtrahend];
  return difference;
}

// useful for debugging:  working range, buffer sizes, and visible range
__attribute__((unused)) static NSString *ASWorkingRangeDebugDescription(NSRange workingRange, NSRange visibleRange)
{
  NSInteger visibleRangeLastElement = NSMaxRange(visibleRange) - 1;
  NSInteger workingRangeLastElement = NSMaxRange(workingRange) - 1;
  return [NSString stringWithFormat:@"[%zd(%zd) [%zd, %zd] (%zd)%zd]",
          workingRange.location,
          visibleRange.location - workingRange.location,
          visibleRange.location,
          visibleRangeLastElement,
          workingRangeLastElement - visibleRangeLastElement,
          workingRangeLastElement];
}

#pragma mark NSRange <-> NSIndexPath.

static BOOL ASRangeIsValid(NSRange range)
{
  return range.location != NSNotFound && range.length > 0;
}

- (NSIndexPath *)indexPathForIndex:(NSInteger)index
{
  ASDisplayNodeAssert(index < _totalNodeCount, @"invalid argument");

  for (NSInteger section = _sectionCounts.count - 1; section >= 0; section--) {
    NSInteger offset = [_sectionOffsets[section] integerValue];
    if (offset <= index) {
      return [NSIndexPath indexPathForRow:index - offset inSection:section];
    }
  }

  ASDisplayNodeAssert(NO, @"logic error");
  return nil;
}

- (NSArray *)indexPathsForRange:(NSRange)range
{
  ASDisplayNodeAssert(ASRangeIsValid(range) && NSMaxRange(range) <= _totalNodeCount, @"invalid argument");

  NSMutableArray *result = [NSMutableArray arrayWithCapacity:range.length];

  NSIndexPath *indexPath = [self indexPathForIndex:range.location];
  for (NSInteger i = range.location; i < NSMaxRange(range); i++) {
    [result addObject:indexPath];

    if (indexPath.row + 1 >= [_sectionCounts[indexPath.section] integerValue]) {
      indexPath = [NSIndexPath indexPathForRow:0 inSection:indexPath.section + 1];
    } else {
      indexPath = [NSIndexPath indexPathForRow:indexPath.row + 1 inSection:indexPath.section];
    }
  }

  return result;
}

- (NSInteger)indexForIndexPath:(NSIndexPath *)indexPath
{
  NSInteger index = [_sectionOffsets[indexPath.section] integerValue] + indexPath.row;
  ASDisplayNodeAssert(index < _totalNodeCount, @"invalid argument");
  return index;
}

#pragma mark View manipulation.

- (void)discardNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  NSInteger index = [self indexForIndexPath:node.asyncdisplaykit_indexPath];
  if (NSLocationInRange(index, _workingRange)) {
    // move the node's view to the working range area, so its rendering persists
    [self moveNodeToWorkingView:node];
  } else {
    // this node isn't in the working range, remove it from the view hierarchy
    [self removeNodeFromWorkingView:node];
  }
}

- (void)removeNodeFromWorkingView:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  [node recursiveSetPreventOrCancelDisplay:YES];
  [node.view removeFromSuperview];
  
  // since this class usually manages large or infinite data sets, the working range
  // directly bounds memory usage by requiring redrawing any content that falls outside the range.
  [node recursivelyReclaimMemory];
  
  [_workingIndexPaths removeObject:node.asyncdisplaykit_indexPath];
}

- (void)moveNodeToWorkingView:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  [self moveNode:node toView:[ASRangeController workingView]];
  [_workingIndexPaths addObject:node.asyncdisplaykit_indexPath];
}

- (void)moveNode:(ASCellNode *)node toView:(UIView *)view
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node && view, @"invalid argument, did you mean -removeNodeFromWorkingView:?");

  // use an explicit transaction to force CoreAnimation to display nodes in the order they are added.
  [CATransaction begin];

  [view addSubview:node.view];
  
  [CATransaction commit];
}


#pragma mark -
#pragma mark API.

- (void)recalculateDataSourceCounts
{
  // data source information (_sectionCounts, _sectionOffsets, _totalNodeCount) is not currently thread-safe
  ASDisplayNodeAssertMainThread();

  NSInteger sections = [_delegate rangeControllerSections:self];

  NSMutableArray *sectionCounts = [NSMutableArray arrayWithCapacity:sections];
  for (NSInteger section = 0; section < sections; section++) {
    sectionCounts[section] = @([_delegate rangeController:self rowsInSection:section]);
  }

  NSMutableArray *sectionOffsets = [NSMutableArray arrayWithCapacity:sections];
  NSInteger offset = 0;
  for (NSInteger section = 0; section < sections; section++) {
    sectionOffsets[section] = @(offset);
    offset += [sectionCounts[section] integerValue];
  }

  _sectionCounts = sectionCounts;
  _sectionOffsets = sectionOffsets;
  _totalNodeCount = offset;
}

- (void)rebuildData
{
  /*
   * teardown
   */
  [self teardownAllNodes];

  /*
   * setup
   */
  [self recalculateDataSourceCounts];
  _nodes = [NSMutableDictionary dictionaryWithCapacity:_totalNodeCount];
  _visibleRange = _workingRange = NSMakeRange(NSNotFound, 0);
  _sizedNodeCount = 0;
  _nodeSizes = [NSMutableArray array];
  _scrollDirection = ASScrollDirectionDown;
  _workingIndexPaths = [NSMutableOrderedSet orderedSet];

  // don't bother sizing if the data source is empty
  if (_totalNodeCount > 0) {
    [self sizeNextBlock];
  }
}

- (void)visibleNodeIndexPathsDidChange
{
  if (_queuedRangeUpdate)
    return;

  // coalesce these events -- handling them multiple times per runloop is noisy and expensive
  _queuedRangeUpdate = YES;
  [self performSelector:@selector(updateVisibleNodeIndexPaths)
             withObject:nil
             afterDelay:0
                inModes:@[ NSRunLoopCommonModes ]];
}

- (void)updateVisibleNodeIndexPaths
{
  NSArray *indexPaths = [_delegate rangeControllerVisibleNodeIndexPaths:self];
  if (indexPaths.count) {
    [self setVisibleRange:NSMakeRange([self indexForIndexPath:[indexPaths firstObject]],
                                      indexPaths.count)];
  }

  _queuedRangeUpdate = NO;
}

- (NSInteger)numberOfSizedSections
{
  // short-circuit if we haven't started sizing
  if (_sizedNodeCount == 0)
    return 0;

  NSIndexPath *lastSizedIndex = [self indexPathForIndex:_sizedNodeCount - 1];
  NSInteger sizedSectionCount = lastSizedIndex.section + 1;

  ASDisplayNodeAssert(sizedSectionCount <= _sectionCounts.count, @"logic error");
  return sizedSectionCount;
}

- (NSInteger)numberOfSizedRowsInSection:(NSInteger)section
{
  // short-circuit if we haven't started sizing
  if (_sizedNodeCount == 0)
    return 0;

  if (section > _sectionCounts.count) {
    ASDisplayNodeAssert(NO, @"this isn't even a valid section");
    return 0;
  }

  NSIndexPath *lastSizedIndex = [self indexPathForIndex:_sizedNodeCount - 1];
  if (section > lastSizedIndex.section) {
    ASDisplayNodeAssert(NO, @"this section hasn't been sized yet");
    return 0;
  } else if (section == lastSizedIndex.section) {
    // we're still sizing this section, return the count we have
    return lastSizedIndex.row + 1;
  } else {
    // we've already sized beyond this section, return the full count
    return [_sectionCounts[section] integerValue];
  }
}

- (void)configureContentView:(UIView *)contentView forIndexPath:(NSIndexPath *)indexPath
{
  ASCellNode *newNode = [self sizedNodeForIndexPath:indexPath];
  ASDisplayNodeAssert(newNode, @"this node hasn't been sized yet!");

  if (newNode.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }

  for (UIView *view in contentView.subviews) {
    ASDisplayNode *node = view.asyncdisplaykit_node;
    if (node) {
      // plunk this node back into the working range, if appropriate
      ASDisplayNodeAssert([node isKindOfClass:[ASCellNode class]], @"invalid node");
      [self discardNode:(ASCellNode *)node];
    } else {
      // if it's not a node, it's something random UITableView added to the hierarchy.  kill it.
      [view removeFromSuperview];
    }
  }

  [self moveNode:newNode toView:contentView];
}

- (CGSize)calculatedSizeForNodeAtIndexPath:(NSIndexPath *)indexPath
{
  // TODO add an assertion (here or in ASTableView) that the calculated size isn't bogus (eg must be < tableview width)
  ASCellNode *node = [self sizedNodeForIndexPath:indexPath];
  return node.calculatedSize;
}


#pragma mark -
#pragma mark Working range.

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters
{
  _tuningParameters = tuningParameters;

  if (ASRangeIsValid(_visibleRange)) {
    [self recalculateWorkingRange];
  }
}

static NSRange ASCalculateWorkingRange(ASRangeTuningParameters params, ASScrollDirection scrollDirection,
                                       NSRange visibleRange, NSArray *nodeSizes, CGSize viewport)
{
  ASDisplayNodeCAssert(NSMaxRange(visibleRange) <= nodeSizes.count, @"nodes can't be visible until they're sized");

  // extend the visible range by enough nodes to fill at least the requested number of screenfuls
  // NB.  this logic assumes (UITableView-style) vertical scrolling and would need to be changed for ASCollectionView
  CGFloat minUpperBufferSize, minLowerBufferSize;
  switch (scrollDirection) {
    case ASScrollDirectionUp:
      minUpperBufferSize = viewport.height * params.leadingBufferScreenfuls;
      minLowerBufferSize = viewport.height * params.trailingBufferScreenfuls;
      break;

    case ASScrollDirectionDown:
      minUpperBufferSize = viewport.height * params.trailingBufferScreenfuls;
      minLowerBufferSize = viewport.height * params.leadingBufferScreenfuls;
      break;
  }

  // "top" buffer (above the screen, if we're scrolling vertically)
  NSInteger upperBuffer = 0;
  CGFloat upperBufferHeight = 0.0f;
  for (NSInteger idx = visibleRange.location - 1; idx >= 0 && upperBufferHeight < minUpperBufferSize; idx--) {
    upperBuffer++;
    upperBufferHeight += [nodeSizes[idx] CGSizeValue].height;
  }

  // "bottom" buffer (below the screen, if we're scrolling vertically)
  NSInteger lowerBuffer = 0;
  CGFloat lowerBufferHeight = 0.0f;
  for (NSInteger idx = NSMaxRange(visibleRange); idx < nodeSizes.count && lowerBufferHeight < minLowerBufferSize; idx++) {
    lowerBuffer++;
    lowerBufferHeight += [nodeSizes[idx] CGSizeValue].height;
  }

  return NSMakeRange(visibleRange.location - upperBuffer,
                     visibleRange.length + upperBuffer + lowerBuffer);
}

- (void)setVisibleRange:(NSRange)visibleRange
{
  if (NSEqualRanges(_visibleRange, visibleRange))
    return;

  ASDisplayNodeAssert(ASRangeIsValid(visibleRange), @"invalid argument");
  NSRange previouslyVisible = ASRangeIsValid(_visibleRange) ? _visibleRange : visibleRange;
  _visibleRange = visibleRange;

  // figure out where we're going, because that's where the bulk of the working range needs to be
  NSInteger scrollDelta = _visibleRange.location - previouslyVisible.location;
  if (scrollDelta < 0)
    _scrollDirection = ASScrollDirectionUp;
  if (scrollDelta > 0)
    _scrollDirection = ASScrollDirectionDown;

  [self recalculateWorkingRange];
}

- (void)recalculateWorkingRange
{
  NSRange workingRange = ASCalculateWorkingRange(_tuningParameters,
                                                 _scrollDirection,
                                                 _visibleRange,
                                                 _nodeSizes,
                                                 [_delegate rangeControllerViewportSize:self]);
  [self setWorkingRange:workingRange];
}

- (void)setWorkingRange:(NSRange)newWorkingRange
{
  if (NSEqualRanges(_workingRange, newWorkingRange))
    return;

  // the working range is a superset of the visible range, but we only care about offscreen nodes
  ASDisplayNodeAssert(NSEqualRanges(_visibleRange, NSIntersectionRange(_visibleRange, newWorkingRange)), @"logic error");
  NSOrderedSet *visibleIndexPaths = [NSOrderedSet orderedSetWithArray:[self indexPathsForRange:_visibleRange]];
  NSOrderedSet *oldWorkingIndexPaths = ASCopySetMinusSet(_workingIndexPaths, visibleIndexPaths);
  NSOrderedSet *newWorkingIndexPaths = ASCopySetMinusSet([NSOrderedSet orderedSetWithArray:[self indexPathsForRange:newWorkingRange]], visibleIndexPaths);

  // update bookkeeping for visible nodes; these will be removed from the working range later in -configureContentView::
  [_workingIndexPaths minusOrderedSet:visibleIndexPaths];

  // evict nodes that have left the working range (i.e., those that are in the old working range but not the new one)
  NSOrderedSet *removedIndexPaths = ASCopySetMinusSet(oldWorkingIndexPaths, newWorkingIndexPaths);
  for (NSIndexPath *indexPath in removedIndexPaths) {
    ASCellNode *node = [self sizedNodeForIndexPath:indexPath];
    ASDisplayNodeAssert(node, @"an unsized node should never have entered the working range");
    [self removeNodeFromWorkingView:node];
  }

  // add nodes that have entered the working range (i.e., those that are in the new working range but not the old one)
  NSOrderedSet *addedIndexPaths = ASCopySetMinusSet(newWorkingIndexPaths, oldWorkingIndexPaths);
  for (NSIndexPath *indexPath in addedIndexPaths) {
    // if a node in the working range is still sizing, the sizing logic will add it to the working range for us later
    ASCellNode *node = [self sizedNodeForIndexPath:indexPath];
    if (node) {
      [self moveNodeToWorkingView:node];
    } else {
      ASDisplayNodeAssert(_sizedNodeCount != _totalNodeCount, @"logic error");
    }
  }

  _workingRange = newWorkingRange;
}


#pragma mark -
#pragma mark Async sizing.

- (ASCellNode *)sizedNodeForIndexPath:(NSIndexPath *)indexPath
{
  if ([self indexForIndexPath:indexPath] >= _sizedNodeCount) {
    // this node hasn't been sized yet
    return nil;
  }

  // work around applebug:  a UIMutableIndexPath with row r and section s is not considered equal to an NSIndexPath with
  //                        row r and section s, so we cannot use the provided indexPath directly as a dictionary index.
  ASCellNode *sizedNode = _nodes[[NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section]];
  ASDisplayNodeAssert(sizedNode, @"this node should be sized but doesn't even exist");
  ASDisplayNodeAssert([sizedNode.asyncdisplaykit_indexPath isEqual:indexPath], @"this node has the wrong index path");
  [sizedNode recursiveSetPreventOrCancelDisplay:NO];
  return sizedNode;
}

- (void)sizeNextBlock
{
  // concurrently size as many nodes as the CPU allows
  static const NSInteger blockSize = [[NSProcessInfo processInfo] processorCount];
  NSRange sizingRange = NSMakeRange(_sizedNodeCount, MIN(blockSize, _totalNodeCount - _sizedNodeCount));

  // manage sizing on a throwaway background queue; we'll be blocking it
  dispatch_async(dispatch_queue_create(NULL, DISPATCH_QUEUE_CONCURRENT), ^{
    dispatch_group_t group = dispatch_group_create();

    NSArray *indexPaths = [self indexPathsForRange:sizingRange];
    for (NSIndexPath *indexPath in indexPaths) {
      ASCellNode *node = [_delegate rangeController:self nodeForIndexPath:indexPath];
      node.asyncdisplaykit_indexPath = indexPath;
      _nodes[indexPath] = node;

      dispatch_group_async(group, [ASRangeController sizingQueue], ^{
        [node measure:[_delegate rangeController:self constrainedSizeForNodeAtIndexPath:indexPath]];
        node.frame = CGRectMake(0.0f, 0.0f, node.calculatedSize.width, node.calculatedSize.height);
      });
    }

    // wait for all sizing to finish, then bounce back to main
    // TODO consider using a semaphore here -- we currently don't size nodes while updating the working range
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_async(dispatch_get_main_queue(), ^{
      // update sized node information
      _sizedNodeCount = NSMaxRange(sizingRange);
      for (NSIndexPath *indexPath in indexPaths) {
        ASCellNode *node = _nodes[indexPath];
        _nodeSizes[[self indexForIndexPath:indexPath]] = [NSValue valueWithCGSize:node.calculatedSize];
      }
      ASDisplayNodeAssert(_nodeSizes.count == _sizedNodeCount, @"logic error");

      // update the working range
      if (ASRangeIsValid(_visibleRange)) {
        [self recalculateWorkingRange];
      }

      // delegateify
      [_delegate rangeController:self didSizeNodesWithIndexPaths:indexPaths];

      // kick off the next block
      if (_sizedNodeCount < _totalNodeCount) {
        [self performSelector:@selector(sizeNextBlock) withObject:NULL afterDelay:0];
      }
    });
  });
}


#pragma mark -
#pragma mark Editing.

static BOOL ASIndexPathsAreSequential(NSIndexPath *first, NSIndexPath *second)
{
  BOOL row = (second.row == first.row + 1 && second.section == first.section);
  BOOL section = (second.row == 0 && second.section == first.section + 1);
  return row || section;
}

- (void)appendNodesWithIndexPaths:(NSArray *)indexPaths
{
  // sanity-check input
  // TODO this is proof-of-concept-quality, expand validation when fleshing out update / editing support
  NSIndexPath *lastNode = (_totalNodeCount > 0) ? [self indexPathForIndex:_totalNodeCount - 1] : nil;
  BOOL indexPathsAreValid = ((lastNode && ASIndexPathsAreSequential(lastNode, [indexPaths firstObject])) ||
                             [[indexPaths firstObject] isEqual:[NSIndexPath indexPathForRow:0 inSection:0]]);
  if (!indexPaths || !indexPaths.count || !indexPathsAreValid) {
    ASDisplayNodeAssert(NO, @"invalid argument");
    return;
  }

  // update all the things
  void (^updateBlock)() = ^{
    BOOL isSizing = (_sizedNodeCount < _totalNodeCount);
    NSInteger expectedTotalNodeCount = _totalNodeCount + indexPaths.count;

    [self recalculateDataSourceCounts];
    ASDisplayNodeAssert(_totalNodeCount == expectedTotalNodeCount, @"data source error");

    if (!isSizing) {
      // the last sizing pass completely finished, start a new one
      [self sizeNextBlock];
    }
  };

  // trampoline to main if necessary, we don't have locks on _sectionCounts / _sectionOffsets / _totalNodeCount
  if (![NSThread isMainThread]) {
    dispatch_sync(dispatch_get_main_queue(), ^{
      updateBlock();
    });
  } else {
    updateBlock();
  }
}


@end
