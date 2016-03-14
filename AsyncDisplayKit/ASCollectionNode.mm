//
//  ASCollectionNode.m
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASCollectionNode.h"
#import "ASCollectionInternal.h"
#import "ASCollectionViewLayoutFacilitatorProtocol.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASRangeControllerUpdateRangeProtocol+Beta.h"
#include <vector>

@interface _ASCollectionPendingState : NSObject
@property (weak, nonatomic) id <ASCollectionDelegate>   delegate;
@property (weak, nonatomic) id <ASCollectionDataSource> dataSource;
@end

@implementation _ASCollectionPendingState
@end

#if 0  // This is not used yet, but will provide a way to avoid creating the view to set range values.
@implementation _ASCollectionPendingState
{
  std::vector<ASRangeTuningParameters> _tuningParameters;
}

- (instancetype)init
{
  if (!(self = [super init])) {
    return nil;
  }
  _tuningParameters = std::vector<ASRangeTuningParameters>(ASLayoutRangeTypeCount);
  return self;
}

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  return _tuningParameters[rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssert(rangeType < _tuningParameters.size(), @"Requesting a range that is OOB for the configured tuning parameters");
  ASDisplayNodeAssert(rangeType != ASLayoutRangeTypeVisible, @"Must not set Visible range tuning parameters (always 0, 0)");
  _tuningParameters[rangeType] = tuningParameters;
}

@end
#endif

@interface ASCollectionNode ()
@property (nonatomic) _ASCollectionPendingState *pendingState;
@end

@implementation ASCollectionNode

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

- (instancetype)_initWithCollectionView:(ASCollectionView *)collectionView
{
  ASDisplayNodeViewBlock collectionViewBlock = ^UIView *{ return collectionView; };
  
  if (self = [super initWithViewBlock:collectionViewBlock]) {
    // ASCollectionView created directly by the app.  Trigger -loadView to set up collectionNode pointer.
    __unused ASCollectionView *collectionView = [self view];
    return self;
  }
  return nil;
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  return [self initWithFrame:frame collectionViewLayout:layout layoutFacilitator:nil];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator
{
  ASDisplayNodeViewBlock collectionViewBlock = ^UIView *{
    return [[ASCollectionView alloc] _initWithFrame:frame collectionViewLayout:layout layoutFacilitator:layoutFacilitator ownedByNode:YES];
  };
  
  if (self = [super initWithViewBlock:collectionViewBlock]) {
    return self;
  }
  return nil;
}

- (void)didLoad
{
  [super didLoad];
  
  ASCollectionView *view = self.view;
  view.collectionNode    = self;
  
  if (_pendingState) {
    _ASCollectionPendingState *pendingState = _pendingState;
    self.pendingState      = nil;
    view.asyncDelegate     = pendingState.delegate;
    view.asyncDataSource   = pendingState.dataSource;
  }
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
    self.view.asyncDelegate = delegate;
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
    self.view.asyncDataSource = dataSource;
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

- (ASCollectionView *)view
{
  return (ASCollectionView *)[super view];
}

#if ASRangeControllerLoggingEnabled
- (void)visibilityDidChange:(BOOL)isVisible
{
  [super visibilityDidChange:isVisible];
  NSLog(@"%@ - visible: %d", self, isVisible);
}
#endif

- (void)clearContents
{
  [super clearContents];
  [self.view clearContents];
}

- (void)clearFetchedData
{
  [super clearFetchedData];
  [self.view clearFetchedData];
}

- (void)beginUpdates
{
  [self.view.dataController beginUpdates];
}

- (void)endUpdatesAnimated:(BOOL)animated
{
  [self endUpdatesAnimated:animated completion:nil];
}

- (void)endUpdatesAnimated:(BOOL)animated completion:(void (^)(BOOL))completion
{
  [self.view.dataController endUpdatesAnimated:animated completion:completion];
}

#pragma mark - ASCollectionView Forwards

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self.view.rangeController tuningParametersForRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  [self.view.rangeController setTuningParameters:tuningParameters forRangeMode:ASLayoutRangeModeFull rangeType:rangeType];
}

- (ASRangeTuningParameters)tuningParametersForRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.view.rangeController tuningParametersForRangeMode:rangeMode rangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeMode:(ASLayoutRangeMode)rangeMode rangeType:(ASLayoutRangeType)rangeType
{
  return [self.view.rangeController setTuningParameters:tuningParameters forRangeMode:rangeMode rangeType:rangeType];
}

- (void)updateCurrentRangeWithMode:(ASLayoutRangeMode)rangeMode;
{
  [self.view.rangeController updateCurrentRangeWithMode:rangeMode];
}

- (void)reloadDataWithCompletion:(void (^)())completion
{
  [self.view reloadDataWithCompletion:completion];
}

- (void)reloadData
{
  [self.view reloadData];
}

- (void)reloadDataImmediately
{
  [self.view reloadDataImmediately];
}

@end
