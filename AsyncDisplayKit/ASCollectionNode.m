//
//  ASCollectionNode.m
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASCollectionNode.h"

@implementation ASCollectionNode

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
  self = [self initWithCollectionViewLayout:nil]; // Will throw an exception for lacking a UICV Layout.
  return nil;
}

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout
{
  if (self = [super initWithViewBlock:^UIView *{ return [[ASCollectionView alloc] initWithCollectionViewLayout:layout]; }]) {
    return self;
  }
  return nil;
}

- (ASCollectionView *)view
{
  return (ASCollectionView *)[super view];
}

@end
