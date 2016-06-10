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
#import "KittenNode.h"
#import "OverrideViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import <AsyncDisplayKit/ASAssert.h>

@interface ViewController ()
@end

@implementation ViewController

#pragma mark -
#pragma mark UIViewController.

- (instancetype)init
{
  KittenNode *displayNode = [[KittenNode alloc] init];
  if (!(self = [super initWithNode:displayNode]))
    return nil;

  self.title = @"Display Node";
  displayNode.imageTappedBlock = ^{
    [KittenNode defaultImageTappedAction:self];
  };
  return self;
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
}

@end
