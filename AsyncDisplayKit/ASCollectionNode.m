//
//  ASCollectionNode.m
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASCollectionNode.h"
#import "ASDisplayNode+Subclasses.h"

@interface _ASCollectionPendingState : NSObject
@property (weak, nonatomic) id <ASCollectionDelegate>   delegate;
@property (weak, nonatomic) id <ASCollectionDataSource> dataSource;
@end

@implementation _ASCollectionPendingState
@end

@interface ASCollectionNode ()
@property (nonatomic) _ASCollectionPendingState *pendingState;
@end

@interface ASCollectionView ()
- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout ownedByNode:(BOOL)ownedByNode;
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
  if (self = [super initWithViewBlock:^UIView *{ return collectionView; }]) {
    __unused ASCollectionView *collectionView = [self view];
    return self;
  }
  return nil;
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout
{
  ASDisplayNodeViewBlock collectionViewBlock = ^UIView *{
    return [[ASCollectionView alloc] _initWithFrame:frame collectionViewLayout:layout ownedByNode:YES];
  };
  
  if (self = [super initWithViewBlock:collectionViewBlock]) {
    return self;
  }
  return nil;
}

- (void)didLoad
{
  [super didLoad];
  
  if (_pendingState) {
    _ASCollectionPendingState *pendingState = _pendingState;
    self.pendingState = nil;
    
    ASCollectionView *view = self.view;
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

- (void)visibilityDidChange:(BOOL)isVisible
{
  
}

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

#pragma mark - ASCollectionView Forwards

- (ASRangeTuningParameters)tuningParametersForRangeType:(ASLayoutRangeType)rangeType
{
  return [self.view tuningParametersForRangeType:rangeType];
}

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType
{
  return [self.view setTuningParameters:tuningParameters forRangeType:rangeType];
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
