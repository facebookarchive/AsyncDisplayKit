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

@interface ViewController ()
@property (nonatomic, strong) ASTextNode *textNode;
@end

@implementation ViewController

- (void)viewDidLoad
{
  self.textNode = [[ASTextNode alloc] init];
  self.textNode.attributedString = [[NSAttributedString alloc] initWithString:@"Testing, testing." attributes:@{ NSForegroundColorAttributeName: [UIColor redColor] }];
  [self.textNode measure:self.view.bounds.size];
  self.textNode.frame = (CGRect){ .origin = CGPointZero, .size = self.textNode.calculatedSize };
  [self.view addSubnode:self.textNode];
}

@end
