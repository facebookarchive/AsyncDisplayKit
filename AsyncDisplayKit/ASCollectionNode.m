//
//  ASCollectionNode.m
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASCollectionNode.h"
#import "ASDisplayNode+Subclasses.h"

@interface ASCollectionView (Internal)
- (ASCollectionView *)_initWithCollectionViewLayout:(UICollectionViewLayout *)layout;
@end

@implementation ASCollectionNode

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
  self = [self initWithCollectionViewLayout:nil]; // Will throw an exception for lacking a UICV Layout.
  return nil;
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  if (self = [super initWithViewBlock:^UIView *{ return [[ASCollectionView alloc] _initWithCollectionViewLayout:layout]; }]) {
    return self;
  }
  return nil;
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
