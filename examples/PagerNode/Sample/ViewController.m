//
//  ViewController.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "PageNode.h"

@interface ViewController () <ASPagerNodeDataSource>

- (ASPagerNode *)node;

@end

@implementation ViewController

- (instancetype)init
{
  if (!(self = [super initWithNode:[[ASPagerNode alloc] init]]))
    return nil;

  [self node].dataSource = self;
  
  self.title = @"Pages";

  return self;
}

- (ASPagerNode *)node
{
  return (ASPagerNode *)[super node];
}

#pragma mark - ASPagerNodeDataSource

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
  return 5;
}

- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index
{
  PageNode *page = [[PageNode alloc] init];
  page.backgroundColor = [UIColor blueColor];
  return page;
}

@end
