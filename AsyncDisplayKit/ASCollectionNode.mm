//
//  ASCollectionNode.mm
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASCollectionInternal.h"
#import "ASCollectionViewLayoutFacilitatorProtocol.h"
#import "ASCollectionNode.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASEnvironmentInternal.h"
#import "ASInternalHelpers.h"
#import "ASCellNode+Internal.h"
#import "AsyncDisplayKit+Debug.h"
#import "ASSectionContext.h"
#import "ASCollectionDataController.h"
#import "ASCollectionView+Undeprecated.h"

#pragma mark - _ASCollectionPendingState

@interface _ASCollectionPendingState : NSObject
@property (weak, nonatomic) id <ASCollectionDelegate>   delegate;
@property (weak, nonatomic) id <ASCollectionDataSource> dataSource;
@property (nonatomic, assign) ASLayoutRangeMode rangeMode;
@property (nonatomic, assign) BOOL allowsSelection; // default is YES
@property (nonatomic, assign) BOOL allowsMultipleSelection; // default is NO
@end

@implementation _ASCollectionPendingState

- (instancetype)init
{
  self = [super init];
  if (self) {
    _rangeMode = ASLayoutRangeModeCount;
    _allowsSelection = YES;
    _allowsMultipleSelection = NO;
  }
  return self;
}
@end

// TODO: Add support for tuning parameters in the pending state
#if 0  // This is not used yet, but will provide a way to avoid creating the view to set range values.
@implementation _ASCollectionPendingState {
  std::vector<std::vector<ASRangeTuningParameters>> _tuningParameters;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _tuningParameters = std::vector<std::vector<ASRangeTuningParameters>> (ASLayoutRangeModeCount, std::vector<ASRangeTuningParameters> (ASLayoutRangeTypeCount));
    _rangeMode = ASLayoutRangeModeCount;
  }
  return self;
}

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  return [self setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeMode][rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeMode < _tuningParameters.size() && rangeType < _tuningParameters[rangeMode].size(), @"Setting a range that is OOB for the configured tuning parameters");
  _tuningParameters[rangeMode][rangeType] = tuningParameters;
}

@end
#endif

#pragma mark - ASCollectionNode

@interface ASCollectionNode ()
{
  ASDN::RecursiveMutex _environmentStateLock;
}
@property (nonatomic) _ASCollectionPendingState *pendingState;
@end

@implementation ASCollectionNode

#pragma mark Lifecycle

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
  UICollectionViewLayout *nilLayout = nil;
  self = [self initWithCollectionViewLayout:nilLayout]; // Will throw an exception for lacking a UICV Layout.
  return nil;
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:CGRectZero collectionViewLayout:layout];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:frame collectionViewLayout:layout layoutFacilitator:nil];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator
{
  __weak __typeof__(self) weakSelf = self;
  ASDisplayNodeViewBlock collectionViewBlock = ^UIView *{
    // Variable will be unused if event logging is off.
    __unused __typeof__(self) strongSelf = weakSelf;
    return [[ASCollectionView alloc] _initWithFrame:frame collectionViewLayout:layout layoutFacilitator:layoutFacilitator eventLog:ASDisplayNodeGetEventLog(strongSelf)];
  };

  if (self = [super initWithViewBlock:collectionViewBlock]) {
    return self;
  }
  return nil;
}

#pragma mark ASDisplayNode

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *view = self.view;
  view.collectionNode    = self;
  
  if (_pendingState) {
    _ASCollectionPendingState *pendingState = _pendingState;
    self.pendingState            = nil;
    view.asyncDelegate           = pendingState.delegate;
    view.asyncDataSource         = pendingState.dataSource;
    view.allowsSelection         = pendingState.allowsSelection;
    view.allowsMultipleSelection = pendingState.allowsMultipleSelection;

    if (pendingState.rangeMode != ASLayoutRangeModeCount) {
      [view.rangeController updateCurrentRangeWithMode:pendingState.rangeMode];
    }
  }
}

- (ASCollectionView *)view
{
  return (ASCollectionView *)[super view];
}

- (void)clearContents
{
  [super clearContents];
  [self.rangeController clearContents];
}

- (void)didExitPreloadState
{
  [super didExitPreloadState];
  [self.rangeController clearPreloadedData];
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  [super interfaceStateDidChange:newState fromState:oldState];
  [ASRangeController layoutDebugOverlayIfNeeded];
}

#if ASRangeControllerLoggingEnabled
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  NSLog(@"%@ - visible: YES", self);
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];
  NSLog(@"%@ - visible: NO", self);
}
#endif

#pragma mark Setter / Getter

// TODO: Implement this without the view.
- (ASCollectionDataController *)dataController
{
  return (ASCollectionDataController *)self.view.dataController;
}

// TODO: Implement this without the view.
- (ASRangeController *)rangeController
{
  return self.view.rangeController;
}

- (_ASCollectionPendingState *)pendingState
{
  if (!_pendingState && ![self isNodeLoaded]) {
    self.pendingState = [[_ASCollectionPendingState alloc] init];
  }
  ASDisplayNodeAssert(![self isNodeLoaded] || !_pendingState, @"ASCollectionNode should not have a pendingState once it is loaded");
  return _pendingState;
}

- (void)setDelegate:(id <ASCollectionDelegate>)delegate
{
  if ([self pendingState]) {
    _pendingState.delegate = delegate;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");

    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASCollectionView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDelegate = delegate;
    });
  }
}

- (id <ASCollectionDelegate>)delegate
{
  if ([self pendingState]) {
    return _pendingState.delegate;
  } else {
    return self.view.asyncDelegate;
  }
}

- (void)setDataSource:(id <ASCollectionDataSource>)dataSource
{
  if ([self pendingState]) {
    _pendingState.dataSource = dataSource;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    // Manually trampoline to the main thread. The view requires this be called on main
    // and asserting here isn't an option – it is a common pattern for users to clear
    // the delegate/dataSource in dealloc, which may be running on a background thread.
    // It is important that we avoid retaining self in this block, so that this method is dealloc-safe.
    ASCollectionView *view = self.view;
    ASPerformBlockOnMainThread(^{
      view.asyncDataSource = dataSource;
    });
  }
}

- (id <ASCollectionDataSource>)dataSource
{
  if ([self pendingState]) {
    return _pendingState.dataSource;
  } else {
    return self.view.asyncDataSource;
  }
}

- (void)setAllowsSelection:(BOOL)allowsSelection
{
  if ([self pendingState]) {
    _pendingState.allowsSelection = allowsSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.allowsSelection = allowsSelection;
  }
}

- (BOOL)allowsSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsSelection;
  } else {
    return self.view.allowsSelection;
  }
}

- (void)setAllowsMultipleSelection:(BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    _pendingState.allowsMultipleSelection = allowsMultipleSelection;
  } else {
    ASDisplayNodeAssert([self isNodeLoaded], @"ASCollectionNode should be loaded if pendingState doesn't exist");
    self.view.allowsMultipleSelection = allowsMultipleSelection;
  }
}

- (BOOL)allowsMultipleSelection
{
  if ([self pendingState]) {
    return _pendingState.allowsMultipleSelection;
  } else {
    return self.view.allowsMultipleSelection;
  }
}

#pragma mark - Range Tuning

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [self.rangeController setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.rangeController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

#pragma mark - Selection

- (NSArray<NSIndexPath *> *)indexPathsForSelectedItems
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *view = self.view;
  return [view convertIndexPathsToCollectionNode:view.indexPathsForSelectedItems];
}

- (void)selectItemAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
  } else {
    NSLog(@"Failed to select item at index path %@ because the item never reached the view.", indexPath);
  }
}

- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView deselectItemAtIndexPath:indexPath animated:animated];
  } else {
    NSLog(@"Failed to deselect item at index path %@ because the item never reached the view.", indexPath);
  }
}

- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];

  if (indexPath != nil) {
    [collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:scrollPosition animated:animated];
  } else {
    NSLog(@"Failed to scroll to item at index path %@ because the item never reached the view.", indexPath);
  }
}

#pragma mark - Querying Data

- (void)reloadDataInitiallyIfNeeded
{
  if (!self.dataController.initialReloadDataHasBeenCalled) {
    [self reloadData];
  }
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController numberOfRowsInSection:section];
}

- (NSInteger)numberOfSections
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController numberOfSections];
}

- (NSArray<__kindof ASCellNode *> *)visibleNodes
{
  ASDisplayNodeAssertMainThread();
  return self.isNodeLoaded ? [self.view visibleNodes] : @[];
}

- (ASCellNode *)nodeForItemAtIndexPath:(NSIndexPath *)indexPath
{
  [self reloadDataInitiallyIfNeeded];
  return [self.dataController nodeAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForNode:(ASCellNode *)cellNode
{
  return [self.dataController indexPathForNode:cellNode];
}

- (NSArray<NSIndexPath *> *)indexPathsForVisibleItems
{
  ASDisplayNodeAssertMainThread();
  NSMutableArray *indexPathsArray = [NSMutableArray new];
  for (ASCellNode *cell in [self visibleNodes]) {
    NSIndexPath *indexPath = [self indexPathForNode:cell];
    if (indexPath) {
      [indexPathsArray addObject:indexPath];
    }
  }
  return indexPathsArray;
}

- (nullable NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  NSIndexPath *indexPath = [collectionView indexPathForItemAtPoint:point];
  if (indexPath != nil) {
    return [collectionView convertIndexPathToCollectionNode:indexPath];
  }
  return indexPath;
}

- (nullable UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  ASDisplayNodeAssertMainThread();
  ASCollectionView *collectionView = self.view;

  indexPath = [collectionView convertIndexPathFromCollectionNode:indexPath waitingIfNeeded:YES];
  if (indexPath == nil) {
    return nil;
  }
  return [collectionView cellForItemAtIndexPath:indexPath];
}

- (id<ASSectionContext>)contextForSection:(NSInteger)section
{
  ASDisplayNodeAssertMainThread();
  return [self.dataController contextForSection:section];
}

#pragma mark - Editing

- (void)registerSupplementaryNodeOfKind:(NSString *)elementKind
{
  [self.view registerSupplementaryNodeOfKind:elementKind];
}

- (void)performBatchAnimated:(BOOL)animated updates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self.view performBatchAnimated:animated updates:updates completion:completion];
}

- (void)performBatchUpdates:(void (^)())updates completion:(void (^)(BOOL))completion
{
  [self.view performBatchUpdates:updates completion:completion];
}

- (void)waitUntilAllUpdatesAreCommitted
{
  [self.view waitUntilAllUpdatesAreCommitted];
}

- (void)reloadDataWithCompletion:(void (^)())completion
{
  [self.view reloadDataWithCompletion:completion];
}

- (void)reloadData
{
  [self.view reloadData];
}

- (void)relayoutItems
{
  [self.view relayoutItems];
}

- (void)reloadDataImmediately
{
  [self.view reloadDataImmediately];
}

- (void)beginUpdates
{
  [self.dataController beginUpdates];
}

- (void)endUpdatesAnimated:(BOOL)animated
{
  [self endUpdatesAnimated:animated completion:nil];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  [self.dataController endUpdatesAnimated:animated completion:completion];
}

- (void)insertSections:(NSIndexSet *)sections
{
  [self.view insertSections:sections];
}

- (void)deleteSections:(NSIndexSet *)sections
{
  [self.view deleteSections:sections];
}

- (void)reloadSections:(NSIndexSet *)sections
{
  [self.view reloadSections:sections];
}

- (void)moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
  [self.view moveSection:section toSection:newSection];
}

- (void)insertItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self.view insertItemsAtIndexPaths:indexPaths];
}

- (void)deleteItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self.view deleteItemsAtIndexPaths:indexPaths];
}

- (void)reloadItemsAtIndexPaths:(NSArray *)indexPaths
{
  [self.view reloadItemsAtIndexPaths:indexPaths];
}

- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath
{
  [self.view moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
}

#pragma mark - ASRangeControllerUpdateRangeProtocol

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;
{
  if ([self pendingState]) {
    _pendingState.rangeMode = rangeMode;
  } else {
    [self.rangeController updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark ASEnvironment

ASEnvironmentCollectionTableSetEnvironmentState(_environmentStateLock)

#pragma mark - Debugging (Private)

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [super propertiesForDebugDescription];
  [result addObject:@{ @"dataSource" : ASObjectDescriptionMakeTiny(self.dataSource) }];
  [result addObject:@{ @"delegate" : ASObjectDescriptionMakeTiny(self.delegate) }];
  return result;
}

@end
