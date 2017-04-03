//
//  ASRangeController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASRangeController.h>

#import <AsyncDisplayKit/_ASHierarchyChangeSet.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h> // Required for interfaceState and hierarchyState setter methods.
#import <AsyncDisplayKit/ASElementMap.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASTwoDimensionalArrayUtils.h>
#import <AsyncDisplayKit/ASWeakSet.h>

#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>

#define AS_RANGECONTROLLER_LOG_UPDATE_FREQ 0

#ifndef ASRangeControllerAutomaticLowMemoryHandling
#define ASRangeControllerAutomaticLowMemoryHandling 1
#endif

@interface ASRangeController ()
{
  BOOL _rangeIsValid;
  BOOL _needsRangeUpdate;
  NSSet<NSIndexPath *> *_allPreviousIndexPaths;
  ASWeakSet<ASCellNode *> *_visibleNodes;
  ASLayoutRangeMode _currentRangeMode;
  BOOL _preserveCurrentRangeMode;
  BOOL _didRegisterForNodeDisplayNotifications;
  CFTimeInterval _pendingDisplayNodesTimestamp;

  // If the user is not currently scrolling, we will keep our ranges
  // configured to match their previous scroll direction. Defaults
  // to [.right, .down] so that when the user first opens a screen
  // the ranges point down into the content.
  ASScrollDirection _previousScrollDirection;
  
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  NSUInteger _updateCountThisFrame;
  CADisplayLink *_displayLink;
#endif
}

@end

static UIApplicationState __ApplicationState = UIApplicationStateActive;

@implementation ASRangeController

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  
  _rangeIsValid = YES;
  _currentRangeMode = ASLayoutRangeModeUnspecified;
  _preserveCurrentRangeMode = NO;
  _previousScrollDirection = ASScrollDirectionDown | ASScrollDirectionRight;
  
  [[[self class] allRangeControllersWeakSet] addObject:self];
  
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_updateCountDisplayLinkDidFire)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
#endif
  
  if (ASDisplayNode.shouldShowRangeDebugOverlay) {
    [self addRangeControllerToRangeDebugOverlay];
  }
  
  return self;
}

- (void)dealloc
{
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  [_displayLink invalidate];
#endif
  
  if (_didRegisterForNodeDisplayNotifications) {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASRenderingEngineDidDisplayScheduledNodesNotification object:nil];
  }
}

#pragma mark - Core visible node range management API

+ (BOOL)isFirstRangeUpdateForRangeMode:(ASLayoutRangeMode)rangeMode
{
  return (rangeMode == ASLayoutRangeModeUnspecified);
}

+ (ASLayoutRangeMode)rangeModeForInterfaceState:(ASInterfaceState)interfaceState
                               currentRangeMode:(ASLayoutRangeMode)currentRangeMode
{
  BOOL isVisible = (ASInterfaceStateIncludesVisible(interfaceState));
  BOOL isFirstRangeUpdate = [self isFirstRangeUpdateForRangeMode:currentRangeMode];
  if (!isVisible || isFirstRangeUpdate) {
    return ASLayoutRangeModeMinimum;
  }
  
  return ASLayoutRangeModeFull;
}

- (ASInterfaceState)interfaceState
{
  ASInterfaceState selfInterfaceState = ASInterfaceStateNone;
  if (_dataSource) {
    selfInterfaceState = [_dataSource interfaceStateForRangeController:self];
  }
  if (__ApplicationState == UIApplicationStateBackground) {
    // If the app is background, pretend to be invisible so that we inform each cell it is no longer being viewed by the user
    selfInterfaceState &= ~(ASInterfaceStateVisible);
  }
  return selfInterfaceState;
}

- (void)setNeedsUpdate
{
  if (!_needsRangeUpdate) {
    _needsRangeUpdate = YES;
      
    __weak __typeof__(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf updateIfNeeded];
    });
  }
}

- (void)updateIfNeeded
{
  if (_needsRangeUpdate) {
    _needsRangeUpdate = NO;
      
    [self _updateVisibleNodeIndexPaths];
  }
}

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode
{
  _preserveCurrentRangeMode = YES;
  if (_currentRangeMode != rangeMode) {
    _currentRangeMode = rangeMode;

    [self setNeedsUpdate];
  }
}

- (void)setLayoutController:(id<ASLayoutController>)layoutController
{
  _layoutController = layoutController;
  if (layoutController && _dataSource) {
    [self updateIfNeeded];
  }
}

- (void)setDataSource:(id<ASRangeControllerDataSource>)dataSource
{
  _dataSource = dataSource;
  if (dataSource && _layoutController) {
    [self updateIfNeeded];
  }
}

// Clear the visible bit from any nodes that disappeared since last update.
// Currently we guarantee that nodes will not be marked visible when deallocated,
// but it's OK to be in e.g. the preload range. So for the visible bit specifically,
// we add this extra mechanism to account for e.g. deleted items.
//
// NOTE: There is a minor risk here, if a node is transferred from one range controller
// to another before the first rc updates and clears the node out of this set. It's a pretty
// wild scenario that I doubt happens in practice.
- (void)_setVisibleNodes:(ASWeakSet *)newVisibleNodes
{
  for (ASCellNode *node in _visibleNodes) {
    if (![newVisibleNodes containsObject:node] && node.isVisible) {
      [node exitInterfaceState:ASInterfaceStateVisible];
    }
  }
  _visibleNodes = newVisibleNodes;
}

- (void)_updateVisibleNodeIndexPaths
{
  ASDisplayNodeAssert(_layoutController, @"An ASLayoutController is required by ASRangeController");
  if (!_layoutController || !_dataSource) {
    return;
  }
  
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  _updateCountThisFrame += 1;
#endif
  
  ASElementMap *map = [_dataSource elementMapForRangeController:self];

  // TODO: Consider if we need to use this codepath, or can rely on something more similar to the data & display ranges
  // Example: ... = [_layoutController indexPathsForScrolling:scrollDirection rangeType:ASLayoutRangeTypeVisible];
  NSSet<ASCollectionElement *> *visibleElements = [NSSet setWithArray:[_dataSource visibleElementsForRangeController:self]];
  ASWeakSet *newVisibleNodes = [[ASWeakSet alloc] init];

  if (visibleElements.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    [self _setVisibleNodes:newVisibleNodes];
    return; // don't do anything for this update, but leave _rangeIsValid == NO to make sure we update it later
  }
  ASProfilingSignpostStart(1, self);

  // Get the scroll direction. Default to using the previous one, if they're not scrolling.
  ASScrollDirection scrollDirection = [_dataSource scrollDirectionForRangeController:self];
  if (scrollDirection == ASScrollDirectionNone) {
    scrollDirection = _previousScrollDirection;
  }
  _previousScrollDirection = scrollDirection;
  
  ASInterfaceState selfInterfaceState = [self interfaceState];
  ASLayoutRangeMode rangeMode = _currentRangeMode;
  // If the range mode is explicitly set via updateCurrentRangeWithMode: it will last in that mode until the
  // range controller becomes visible again or explicitly changes the range mode again
  if ((!_preserveCurrentRangeMode && ASInterfaceStateIncludesVisible(selfInterfaceState)) || [[self class] isFirstRangeUpdateForRangeMode:rangeMode]) {
    rangeMode = [ASRangeController rangeModeForInterfaceState:selfInterfaceState currentRangeMode:_currentRangeMode];
  }

  ASRangeTuningParameters parametersPreload = [_layoutController tuningParametersForRangeMode:rangeMode
                                                                                    rangeType:ASLayoutRangeTypePreload];
  ASRangeTuningParameters parametersDisplay = [_layoutController tuningParametersForRangeMode:rangeMode
                                                                                    rangeType:ASLayoutRangeTypeDisplay];

  // Preload can express the ultra-low-memory state with 0, 0 returned for its tuningParameters above, and will match Visible.
  // However, in this rangeMode, Display is not supposed to contain *any* paths -- not even the visible bounds. TuningParameters can't express this.
  BOOL emptyDisplayRange = (rangeMode == ASLayoutRangeModeLowMemory);
  BOOL equalDisplayPreload = ASRangeTuningParametersEqualToRangeTuningParameters(parametersDisplay, parametersPreload);
  BOOL equalDisplayVisible = (ASRangeTuningParametersEqualToRangeTuningParameters(parametersDisplay, ASRangeTuningParametersZero)
                              && emptyDisplayRange == NO);

  // Check if both Display and Preload are unique. If they are, we load them with a single fetch from the layout controller for performance.
  BOOL optimizedLoadingOfBothRanges = (equalDisplayPreload == NO && equalDisplayVisible == NO && emptyDisplayRange == NO);

  NSSet<ASCollectionElement *> *displayElements = nil;
  NSSet<ASCollectionElement *> *preloadElements = nil;
  
  if (optimizedLoadingOfBothRanges) {
    [_layoutController allElementsForScrolling:scrollDirection rangeMode:rangeMode displaySet:&displayElements preloadSet:&preloadElements map:map];
  } else {
    if (emptyDisplayRange == YES) {
      displayElements = [NSSet set];
    } if (equalDisplayVisible == YES) {
      displayElements = visibleElements;
    } else {
      // Calculating only the Display range means the Preload range is either the same as Display or Visible.
      displayElements = [_layoutController elementsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypeDisplay map:map];
    }
    
    BOOL equalPreloadVisible = ASRangeTuningParametersEqualToRangeTuningParameters(parametersPreload, ASRangeTuningParametersZero);
    if (equalDisplayPreload == YES) {
      preloadElements = displayElements;
    } else if (equalPreloadVisible == YES) {
      preloadElements = visibleElements;
    } else {
      preloadElements = [_layoutController elementsForScrolling:scrollDirection rangeMode:rangeMode rangeType:ASLayoutRangeTypePreload map:map];
    }
  }
  
  // For now we are only interested in items. Filter-map out from element to item-index-path.
  NSSet<NSIndexPath *> *visibleIndexPaths = ASSetByFlatMapping(visibleElements, ASCollectionElement *element, [map indexPathForElementIfCell:element]);
  NSSet<NSIndexPath *> *displayIndexPaths = ASSetByFlatMapping(displayElements, ASCollectionElement *element, [map indexPathForElementIfCell:element]);
  NSSet<NSIndexPath *> *preloadIndexPaths = ASSetByFlatMapping(preloadElements, ASCollectionElement *element, [map indexPathForElementIfCell:element]);

  // Prioritize the order in which we visit each.  Visible nodes should be updated first so they are enqueued on
  // the network or display queues before preloading (offscreen) nodes are enqueued.
  NSMutableOrderedSet<NSIndexPath *> *allIndexPaths = [[NSMutableOrderedSet alloc] initWithSet:visibleIndexPaths];
  
  // Typically the preloadIndexPaths will be the largest, and be a superset of the others, though it may be disjoint.
  // Because allIndexPaths is an NSMutableOrderedSet, this adds the non-duplicate items /after/ the existing items.
  // This means that during iteration, we will first visit visible, then display, then preload nodes.
  [allIndexPaths unionSet:displayIndexPaths];
  [allIndexPaths unionSet:preloadIndexPaths];
  
  // Add anything we had applied interfaceState to in the last update, but is no longer in range, so we can clear any
  // range flags it still has enabled.  Most of the time, all but a few elements are equal; a large programmatic
  // scroll or major main thread stall could cause entirely disjoint sets.  In either case we must visit all.
  // Calling "-set" on NSMutableOrderedSet just references the underlying mutable data store, so we must copy it.
  NSSet<NSIndexPath *> *allCurrentIndexPaths = [[allIndexPaths set] copy];
  [allIndexPaths unionSet:_allPreviousIndexPaths];
  _allPreviousIndexPaths = allCurrentIndexPaths;
  
  _currentRangeMode = rangeMode;
  _preserveCurrentRangeMode = NO;
  
  if (!_rangeIsValid) {
    [allIndexPaths addObjectsFromArray:map.itemIndexPaths];
  }
  
#if ASRangeControllerLoggingEnabled
  ASDisplayNodeAssertTrue([visibleIndexPaths isSubsetOfSet:displayIndexPaths]);
  NSMutableArray<NSIndexPath *> *modifiedIndexPaths = (ASRangeControllerLoggingEnabled ? [NSMutableArray array] : nil);
#endif

  for (NSIndexPath *indexPath in allIndexPaths) {
    // Before a node / indexPath is exposed to ASRangeController, ASDataController should have already measured it.
    // For consistency, make sure each node knows that it should measure itself if something changes.
    ASInterfaceState interfaceState = ASInterfaceStateMeasureLayout;
    
    if (ASInterfaceStateIncludesVisible(selfInterfaceState)) {
      if ([visibleIndexPaths containsObject:indexPath]) {
        interfaceState |= (ASInterfaceStateVisible | ASInterfaceStateDisplay | ASInterfaceStatePreload);
      } else {
        if ([preloadIndexPaths containsObject:indexPath]) {
          interfaceState |= ASInterfaceStatePreload;
        }
        if ([displayIndexPaths containsObject:indexPath]) {
          interfaceState |= ASInterfaceStateDisplay;
        }
      }
    } else {
      // If selfInterfaceState isn't visible, then visibleIndexPaths represents what /will/ be immediately visible at the
      // instant we come onscreen.  So, preload and display all of those things, but don't waste resources preloading yet.
      // We handle this as a separate case to minimize set operations for offscreen preloading, including containsObject:.
      
      if ([allCurrentIndexPaths containsObject:indexPath]) {
        // DO NOT set Visible: even though these elements are in the visible range / "viewport",
        // our overall container object is itself not visible yet.  The moment it becomes visible, we will run the condition above
        
        // Set Layout, Preload
        interfaceState |= ASInterfaceStatePreload;
        
        if (rangeMode != ASLayoutRangeModeLowMemory) {
          // Add Display.
          // We might be looking at an indexPath that was previously in-range, but now we need to clear it.
          // In that case we'll just set it back to MeasureLayout.  Only set Display | Preload if in allCurrentIndexPaths.
          interfaceState |= ASInterfaceStateDisplay;
        }
      }
    }

    ASCellNode *node = [map elementForItemAtIndexPath:indexPath].nodeIfAllocated;
    if (node != nil) {
      ASDisplayNodeAssert(node.hierarchyState & ASHierarchyStateRangeManaged, @"All nodes reaching this point should be range-managed, or interfaceState may be incorrectly reset.");
      if (ASInterfaceStateIncludesVisible(interfaceState)) {
        [newVisibleNodes addObject:node];
      }
      // Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
      if (node.interfaceState != interfaceState) {
#if ASRangeControllerLoggingEnabled
        [modifiedIndexPaths addObject:indexPath];
#endif

        BOOL nodeShouldScheduleDisplay = [node shouldScheduleDisplayWithNewInterfaceState:interfaceState];
        [node recursivelySetInterfaceState:interfaceState];

        if (nodeShouldScheduleDisplay) {
          [self registerForNodeDisplayNotificationsForInterfaceStateIfNeeded:selfInterfaceState];
          if (_didRegisterForNodeDisplayNotifications) {
            _pendingDisplayNodesTimestamp = CACurrentMediaTime();
          }
        }
      }
    }
  }

  [self _setVisibleNodes:newVisibleNodes];
  
  // TODO: This code is for debugging only, but would be great to clean up with a delegate method implementation.
  if (ASDisplayNode.shouldShowRangeDebugOverlay) {
    ASScrollDirection scrollableDirections = ASScrollDirectionUp | ASScrollDirectionDown;
    if ([_dataSource isKindOfClass:NSClassFromString(@"ASCollectionView")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
      scrollableDirections = (ASScrollDirection)[_dataSource performSelector:@selector(scrollableDirections)];
#pragma clang diagnostic pop
    }
    
    [self updateRangeController:self
       withScrollableDirections:scrollableDirections
                scrollDirection:scrollDirection
                      rangeMode:rangeMode
        displayTuningParameters:parametersDisplay
        preloadTuningParameters:parametersPreload
                 interfaceState:selfInterfaceState];
  }
  
  _rangeIsValid = YES;
  
#if ASRangeControllerLoggingEnabled
//  NSSet *visibleNodePathsSet = [NSSet setWithArray:visibleNodePaths];
//  BOOL setsAreEqual = [visibleIndexPaths isEqualToSet:visibleNodePathsSet];
//  NSLog(@"visible sets are equal: %d", setsAreEqual);
//  if (!setsAreEqual) {
//    NSLog(@"standard: %@", visibleIndexPaths);
//    NSLog(@"custom: %@", visibleNodePathsSet);
//  }
  [modifiedIndexPaths sortUsingSelector:@selector(compare:)];
  NSLog(@"Range update complete; modifiedIndexPaths: %@", [self descriptionWithIndexPaths:modifiedIndexPaths]);
#endif
  
  ASProfilingSignpostEnd(1, self);
}

#pragma mark - Notification observers

/**
 * If we're in a restricted range mode, but we're going to change to a full range mode soon,
 * go ahead and schedule the transition as soon as all the currently-scheduled rendering is done #1163.
 */
- (void)registerForNodeDisplayNotificationsForInterfaceStateIfNeeded:(ASInterfaceState)interfaceState
{
  // Do not schedule to listen if we're already in full range mode.
  // This avoids updating the range controller during a collection teardown when it is removed
  // from the hierarchy and its data source is cleared, causing UIKit to call -reloadData.
  if (!_didRegisterForNodeDisplayNotifications && _currentRangeMode != ASLayoutRangeModeFull) {
    ASLayoutRangeMode nextRangeMode = [ASRangeController rangeModeForInterfaceState:interfaceState
                                                                   currentRangeMode:_currentRangeMode];
    if (_currentRangeMode != nextRangeMode) {
      [[NSNotificationCenter defaultCenter] addObserver:self
                                               selector:@selector(scheduledNodesDidDisplay:)
                                                   name:ASRenderingEngineDidDisplayScheduledNodesNotification
                                                 object:nil];
      _didRegisterForNodeDisplayNotifications = YES;
    }
  }
}

- (void)scheduledNodesDidDisplay:(NSNotification *)notification
{
  CFAbsoluteTime notificationTimestamp = ((NSNumber *) notification.userInfo[ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp]).doubleValue;
  if (_pendingDisplayNodesTimestamp < notificationTimestamp) {
    // The rendering engine has processed all the nodes this range controller scheduled. Let's schedule a range update
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ASRenderingEngineDidDisplayScheduledNodesNotification object:nil];
    _didRegisterForNodeDisplayNotifications = NO;
    
    [self setNeedsUpdate];
  }
}

#pragma mark - Cell node view handling

- (void)configureContentView:(UIView *)contentView forCellNode:(ASCellNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"Cannot move a nil node to a view");
  ASDisplayNodeAssert(contentView, @"Cannot move a node to a non-existent view");

  if (node.shouldUseUIKitCell) {
    // When using UIKit cells, the ASCellNode is just a placeholder object with a preferredSize.
    // In this case, we should not disrupt the subviews of the contentView.
    return;
  }

  if (node.view.superview == contentView) {
    // this content view is already correctly configured
    return;
  }
  
  // clean the content view
  for (UIView *view in contentView.subviews) {
    [view removeFromSuperview];
  }
  
  [contentView addSubview:node.view];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  [_layoutController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [_layoutController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

#pragma mark - ASDataControllerDelegete

- (void)dataController:(ASDataController *)dataController willUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  if (changeSet.includesReloadData) {
    [self _setVisibleNodes:nil];
  }
  [_delegate rangeController:self willUpdateWithChangeSet:changeSet];
}

- (void)dataController:(ASDataController *)dataController didUpdateWithChangeSet:(_ASHierarchyChangeSet *)changeSet
{
  ASDisplayNodeAssertMainThread();
  _rangeIsValid = NO;
  [_delegate rangeController:self didUpdateWithChangeSet:changeSet];
}

#pragma mark - Memory Management

// Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
- (void)clearContents
{
  for (ASCollectionElement *element in [_dataSource elementMapForRangeController:self]) {
    ASCellNode *node = element.nodeIfAllocated;
    if (ASInterfaceStateIncludesDisplay(node.interfaceState)) {
      [node exitInterfaceState:ASInterfaceStateDisplay];
    }
  }
}

- (void)clearPreloadedData
{
  for (ASCollectionElement *element in [_dataSource elementMapForRangeController:self]) {
    ASCellNode *node = element.nodeIfAllocated;
    if (ASInterfaceStateIncludesPreload(node.interfaceState)) {
      [node exitInterfaceState:ASInterfaceStatePreload];
    }
  }
}

#pragma mark - Class Methods (Application Notification Handlers)

+ (ASWeakSet *)allRangeControllersWeakSet
{
  static ASWeakSet<ASRangeController *> *__allRangeControllersWeakSet;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __allRangeControllersWeakSet = [[ASWeakSet alloc] init];
    [self registerSharedApplicationNotifications];
  });
  return __allRangeControllersWeakSet;
}

+ (void)registerSharedApplicationNotifications
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
#if ASRangeControllerAutomaticLowMemoryHandling
  [center addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif
  [center addObserver:self selector:@selector(didEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
  [center addObserver:self selector:@selector(willEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

static ASLayoutRangeMode __rangeModeForMemoryWarnings = ASLayoutRangeModeLowMemory;
+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode
{
  ASDisplayNodeAssert(rangeMode == ASLayoutRangeModeVisibleOnly || rangeMode == ASLayoutRangeModeLowMemory, @"It is highly inadvisable to engage a larger range mode when a memory warning occurs, as this will almost certainly cause app eviction");
  __rangeModeForMemoryWarnings = rangeMode;
}

+ (void)didReceiveMemoryWarning:(NSNotification *)notification
{
  NSArray *allRangeControllers = [[self allRangeControllersWeakSet] allObjects];
  for (ASRangeController *rangeController in allRangeControllers) {
    BOOL isDisplay = ASInterfaceStateIncludesDisplay([rangeController interfaceState]);
    [rangeController updateCurrentRangeWithMode:isDisplay ? ASLayoutRangeModeVisibleOnly : __rangeModeForMemoryWarnings];
    // There's no need to call needs update as updateCurrentRangeWithMode sets this if necessary.
    [rangeController updateIfNeeded];
  }
  
#if ASRangeControllerLoggingEnabled
  NSLog(@"+[ASRangeController didReceiveMemoryWarning] with controllers: %@", allRangeControllers);
#endif
}

+ (void)didEnterBackground:(NSNotification *)notification
{
  NSArray *allRangeControllers = [[self allRangeControllersWeakSet] allObjects];
  for (ASRangeController *rangeController in allRangeControllers) {
    // We do not want to fully collapse the Display ranges of any visible range controllers so that flashes can be avoided when
    // the app is resumed.  Non-visible controllers can be more aggressively culled to the LowMemory state (see definitions for documentation)
    BOOL isVisible = ASInterfaceStateIncludesVisible([rangeController interfaceState]);
    [rangeController updateCurrentRangeWithMode:isVisible ? ASLayoutRangeModeVisibleOnly : ASLayoutRangeModeLowMemory];
  }
  
  // Because -interfaceState checks __ApplicationState and always clears the "visible" bit if Backgrounded, we must set this after updating the range mode.
  __ApplicationState = UIApplicationStateBackground;
  for (ASRangeController *rangeController in allRangeControllers) {
    // Trigger a range update immediately, as we may not be allowed by the system to run the update block scheduled by changing range mode.
    // There's no need to call needs update as updateCurrentRangeWithMode sets this if necessary.
    [rangeController updateIfNeeded];
  }
  
#if ASRangeControllerLoggingEnabled
  NSLog(@"+[ASRangeController didEnterBackground] with controllers, after backgrounding: %@", allRangeControllers);
#endif
}

+ (void)willEnterForeground:(NSNotification *)notification
{
  NSArray *allRangeControllers = [[self allRangeControllersWeakSet] allObjects];
  __ApplicationState = UIApplicationStateActive;
  for (ASRangeController *rangeController in allRangeControllers) {
    BOOL isVisible = ASInterfaceStateIncludesVisible([rangeController interfaceState]);
    [rangeController updateCurrentRangeWithMode:isVisible ? ASLayoutRangeModeMinimum : ASLayoutRangeModeVisibleOnly];
    // There's no need to call needs update as updateCurrentRangeWithMode sets this if necessary.
    [rangeController updateIfNeeded];
  }
  
#if ASRangeControllerLoggingEnabled
  NSLog(@"+[ASRangeController willEnterForeground] with controllers, after foregrounding: %@", allRangeControllers);
#endif
}

#pragma mark - Debugging

#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
- (void)_updateCountDisplayLinkDidFire
{
  if (_updateCountThisFrame > 1) {
    NSLog(@"ASRangeController %p updated %lu times this frame.", self, (unsigned long)_updateCountThisFrame);
  }
  _updateCountThisFrame = 0;
}
#endif

- (NSString *)descriptionWithIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
  NSMutableString *description = [NSMutableString stringWithFormat:@"%@ %@", [super description], @" allPreviousIndexPaths:\n"];
  for (NSIndexPath *indexPath in indexPaths) {
    ASDisplayNode *node = [[_dataSource elementMapForRangeController:self] elementForItemAtIndexPath:indexPath].nodeIfAllocated;
    ASInterfaceState interfaceState = node.interfaceState;
    BOOL inVisible = ASInterfaceStateIncludesVisible(interfaceState);
    BOOL inDisplay = ASInterfaceStateIncludesDisplay(interfaceState);
    BOOL inPreload = ASInterfaceStateIncludesPreload(interfaceState);
    [description appendFormat:@"indexPath %@, Visible: %d, Display: %d, Preload: %d\n", indexPath, inVisible, inDisplay, inPreload];
  }
  return description;
}

- (NSString *)description
{
  NSArray<NSIndexPath *> *indexPaths = [[_allPreviousIndexPaths allObjects] sortedArrayUsingSelector:@selector(compare:)];
  return [self descriptionWithIndexPaths:indexPaths];
}

@end

@implementation ASDisplayNode (RangeModeConfiguring)

+ (void)setRangeModeForMemoryWarnings:(ASLayoutRangeMode)rangeMode
{
  [ASRangeController setRangeModeForMemoryWarnings:rangeMode];
}

@end
