//
//  ASRangeController.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASRangeController.h"

#import "ASAssert.h"
#import "ASCellNode.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNodeInternal.h"
#import "ASMultidimensionalArrayUtils.h"
#import "ASInternalHelpers.h"
#import "ASMultiDimensionalArrayUtils.h"
#import "ASWeakSet.h"

#import "ASDisplayNode+FrameworkPrivate.h"
#import "AsyncDisplayKit+Debug.h"

#import <sys/kdebug_signpost.h>

#define AS_RANGECONTROLLER_LOG_UPDATE_FREQ 0

@interface ASRangeController ()
{
  BOOL _rangeIsValid;
  BOOL _needsRangeUpdate;
  BOOL _layoutControllerImplementsSetVisibleIndexPaths;
  BOOL _layoutControllerImplementsSetViewportSize;
  NSSet<NSIndexPath *> *_allPreviousIndexPaths;
  ASLayoutRangeMode _currentRangeMode;
  BOOL _didUpdateCurrentRange;
  BOOL _didRegisterForNodeDisplayNotifications;
  CFAbsoluteTime _pendingDisplayNodesTimestamp;
  
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
  _currentRangeMode = ASLayoutRangeModeInvalid;
  _didUpdateCurrentRange = NO;
  
  [[[self class] allRangeControllersWeakSet] addObject:self];
  
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_updateCountDisplayLinkDidFire)];
  [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
#endif
  
  if ([ASRangeController shouldShowRangeDebugOverlay]) {
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
  return (rangeMode == ASLayoutRangeModeInvalid);
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
  if (_currentRangeMode != rangeMode) {
    _currentRangeMode = rangeMode;
    _didUpdateCurrentRange = YES;

    [self setNeedsUpdate];
  }
}

- (void)setLayoutController:(id<ASLayoutController>)layoutController
{
  _layoutController = layoutController;
  _layoutControllerImplementsSetVisibleIndexPaths = [layoutController respondsToSelector:@selector(setVisibleNodeIndexPaths:)];
  _layoutControllerImplementsSetViewportSize = [layoutController respondsToSelector:@selector(setViewportSize:)];
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

- (void)_updateVisibleNodeIndexPaths
{
  ASDisplayNodeAssert(_layoutController, @"An ASLayoutController is required by ASRangeController");
  if (!_layoutController || !_dataSource) {
    return;
  }
  
#if AS_RANGECONTROLLER_LOG_UPDATE_FREQ
  _updateCountThisFrame += 1;
#endif
  
  // allNodes is a 2D array: it contains arrays for each section, each containing nodes.
  NSArray<NSArray *> *allNodes = [_dataSource completedNodes];
  NSUInteger numberOfSections = [allNodes count];

  // TODO: Consider if we need to use this codepath, or can rely on something more similar to the data & display ranges
  // Example: ... = [_layoutController indexPathsForScrolling:scrollDirection rangeType:ASLayoutRangeTypeVisible];
  NSArray<NSIndexPath *> *visibleNodePaths = [_dataSource visibleNodeIndexPathsForRangeController:self];
  
  if (visibleNodePaths.count == 0) { // if we don't have any visibleNodes currently (scrolled before or after content)...
    return; // don't do anything for this update, but leave _rangeIsValid == NO to make sure we update it later
  }
  ASProfilingSignpostStart(1, self);

  ASScrollDirection scrollDirection = [_dataSource scrollDirectionForRangeController:self];
  if (_layoutControllerImplementsSetViewportSize) {
    [_layoutController setViewportSize:[_dataSource viewportSizeForRangeController:self]];
  }
  
  // the layout controller needs to know what the current visible indices are to calculate range offsets
  if (_layoutControllerImplementsSetVisibleIndexPaths) {
    [_layoutController setVisibleNodeIndexPaths:visibleNodePaths];
  }
  
  NSArray<ASDisplayNode *> *currentSectionNodes = nil;
  NSInteger currentSectionIndex = -1; // Set to -1 so we don't match any indexPath.section on the first iteration.
  NSUInteger numberOfNodesInSection = 0;
  
  NSSet<NSIndexPath *> *visibleIndexPaths = [NSSet setWithArray:visibleNodePaths];
  NSSet<NSIndexPath *> *displayIndexPaths = nil;
  NSSet<NSIndexPath *> *preloadIndexPaths = nil;
  
  // Prioritize the order in which we visit each.  Visible nodes should be updated first so they are enqueued on
  // the network or display queues before preloading (offscreen) nodes are enqueued.
  NSMutableOrderedSet<NSIndexPath *> *allIndexPaths = [[NSMutableOrderedSet alloc] initWithSet:visibleIndexPaths];
  
  ASInterfaceState selfInterfaceState = [self interfaceState];
  ASLayoutRangeMode rangeMode = _currentRangeMode;
  // If the range mode is explicitly set via updateCurrentRangeWithMode: it will last in that mode until the
  // range controller becomes visible again or explicitly changes the range mode again
  if ((!_didUpdateCurrentRange && ASInterfaceStateIncludesVisible(selfInterfaceState)) || [[self class] isFirstRangeUpdateForRangeMode:rangeMode]) {
    rangeMode = [ASRangeController rangeModeForInterfaceState:selfInterfaceState currentRangeMode:_currentRangeMode];
  }

  ASRangeTuningParameters parametersPreload = [_layoutController tuningParametersForRangeMode:rangeMode
                                                                                      rangeType:ASLayoutRangeTypePreload];
  if (ASRangeTuningParametersEqualToRangeTuningParameters(parametersPreload, ASRangeTuningParametersZero)) {
    preloadIndexPaths = visibleIndexPaths;
  } else {
    preloadIndexPaths = [_layoutController indexPathsForScrolling:scrollDirection
                                                          rangeMode:rangeMode
                                                          rangeType:ASLayoutRangeTypePreload];
  }
  
  ASRangeTuningParameters parametersDisplay = [_layoutController tuningParametersForRangeMode:rangeMode
                                                                                    rangeType:ASLayoutRangeTypeDisplay];
  if (rangeMode == ASLayoutRangeModeLowMemory) {
    displayIndexPaths = [NSSet set];
  } else if (ASRangeTuningParametersEqualToRangeTuningParameters(parametersDisplay, ASRangeTuningParametersZero)) {
    displayIndexPaths = visibleIndexPaths;
  } else if (ASRangeTuningParametersEqualToRangeTuningParameters(parametersDisplay, parametersPreload)) {
    displayIndexPaths = preloadIndexPaths;
  } else {
    displayIndexPaths = [_layoutController indexPathsForScrolling:scrollDirection
                                                        rangeMode:rangeMode
                                                        rangeType:ASLayoutRangeTypeDisplay];
  }
  
  // Typically the preloadIndexPaths will be the largest, and be a superset of the others, though it may be disjoint.
  // Because allIndexPaths is an NSMutableOrderedSet, this adds the non-duplicate items /after/ the existing items.
  // This means that during iteration, we will first visit visible, then display, then fetch data nodes.
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
  _didUpdateCurrentRange = NO;
  
  if (!_rangeIsValid) {
    [allIndexPaths addObjectsFromArray:ASIndexPathsForTwoDimensionalArray(allNodes)];
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
      // instant we come onscreen.  So, fetch data and display all of those things, but don't waste resources preloading yet.
      // We handle this as a separate case to minimize set operations for offscreen preloading, including containsObject:.
      
      if ([allCurrentIndexPaths containsObject:indexPath]) {
        // DO NOT set Visible: even though these elements are in the visible range / "viewport",
        // our overall container object is itself not visible yet.  The moment it becomes visible, we will run the condition above
        
        // Set Layout, Fetch Data
        interfaceState |= ASInterfaceStatePreload;
        
        if (rangeMode != ASLayoutRangeModeLowMemory) {
          // Add Display.
          // We might be looking at an indexPath that was previously in-range, but now we need to clear it.
          // In that case we'll just set it back to MeasureLayout.  Only set Display | Preload if in allCurrentIndexPaths.
          interfaceState |= ASInterfaceStateDisplay;
        }
      }
    }
    
    NSInteger section = indexPath.section;
    NSInteger row     = indexPath.row;
    
    if (section >= 0 && row >= 0 && section < numberOfSections) {
      if (section != currentSectionIndex) {
        // Often we'll be dealing with indexPaths in the same section, but the set isn't sorted and we may even bounce
        // between the same ones.  Still, this saves dozens of method calls to access the inner array and count.
        currentSectionNodes = allNodes[section];
        numberOfNodesInSection = [currentSectionNodes count];
        currentSectionIndex = section;
      }
      
      if (row < numberOfNodesInSection) {
        ASDisplayNode *node = currentSectionNodes[row];
        
        ASDisplayNodeAssert(node.hierarchyState & ASHierarchyStateRangeManaged, @"All nodes reaching this point should be range-managed, or interfaceState may be incorrectly reset.");
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
              _pendingDisplayNodesTimestamp = CFAbsoluteTimeGetCurrent();
            }
          }
        }
      }
    }
  }
  
  // TODO: This code is for debugging only, but would be great to clean up with a delegate method implementation.
  if ([ASRangeController shouldShowRangeDebugOverlay]) {
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
  [_delegate didCompleteUpdatesInRangeController:self];
  
  ASProfilingSignpostEnd(1, self);
}

#pragma mark - Notification observers

- (void)registerForNodeDisplayNotificationsForInterfaceStateIfNeeded:(ASInterfaceState)interfaceState
{
  if (!_didRegisterForNodeDisplayNotifications) {
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

- (void)dataControllerBeginUpdates:(ASDataController *)dataController
{
  ASDisplayNodeAssertMainThread();
  [_delegate didBeginUpdatesInRangeController:self];
}

- (void)dataController:(ASDataController *)dataController endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  ASDisplayNodeAssertMainThread();
  [_delegate rangeController:self didEndUpdatesAnimated:animated completion:completion];
}

- (void)dataController:(ASDataController *)dataController didInsertNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(nodes.count == indexPaths.count, @"Invalid index path");
  ASDisplayNodeAssertMainThread();
  _rangeIsValid = NO;
  [_delegate rangeController:self didInsertNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
}

- (void)dataController:(ASDataController *)dataController didDeleteNodes:(NSArray *)nodes atIndexPaths:(NSArray *)indexPaths withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  _rangeIsValid = NO;
  [_delegate rangeController:self didDeleteNodes:nodes atIndexPaths:indexPaths withAnimationOptions:animationOptions];
}

- (void)dataController:(ASDataController *)dataController didInsertSections:(NSArray *)sections atIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssert(sections.count == indexSet.count, @"Invalid sections");
  ASDisplayNodeAssertMainThread();
  _rangeIsValid = NO;
  [_delegate rangeController:self didInsertSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
}

- (void)dataController:(ASDataController *)dataController didDeleteSectionsAtIndexSet:(NSIndexSet *)indexSet withAnimationOptions:(ASDataControllerAnimationOptions)animationOptions
{
  ASDisplayNodeAssertMainThread();
  _rangeIsValid = NO;
  [_delegate rangeController:self didDeleteSectionsAtIndexSet:indexSet withAnimationOptions:animationOptions];
}

#pragma mark - Memory Management

// Skip the many method calls of the recursive operation if the top level cell node already has the right interfaceState.
- (void)clearContents
{
  for (NSArray *section in [_dataSource completedNodes]) {
    for (ASDisplayNode *node in section) {
      if (ASInterfaceStateIncludesDisplay(node.interfaceState)) {
        [node exitInterfaceState:ASInterfaceStateDisplay];
      }
    }
  }
}

- (void)clearFetchedData
{
  for (NSArray *section in [_dataSource completedNodes]) {
    for (ASDisplayNode *node in section) {
      if (ASInterfaceStateIncludesPreload(node.interfaceState)) {
        [node exitInterfaceState:ASInterfaceStatePreload];
      }
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

static ASLayoutRangeMode __rangeModeForMemoryWarnings = ASLayoutRangeModeVisibleOnly;
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
    [rangeController updateCurrentRangeWithMode:isDisplay ? ASLayoutRangeModeMinimum : __rangeModeForMemoryWarnings];
    [rangeController setNeedsUpdate];
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
    [rangeController setNeedsUpdate];
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
    [rangeController setNeedsUpdate];
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
    ASDisplayNode *node = [_dataSource rangeController:self nodeAtIndexPath:indexPath];
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
