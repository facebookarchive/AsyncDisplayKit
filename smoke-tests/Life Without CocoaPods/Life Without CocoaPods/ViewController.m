/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ViewController () {
  ASTextNode *_textNode;
}

@end

@implementation ViewController

- (void)viewDidLoad
{
  _textNode = [[ASTextNode alloc] init];
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:@"Testing, testing."];
  [_textNode measure:self.view.bounds.size];
  _textNode.frame = (CGRect){ .origin = CGPointZero, .size = _textNode.calculatedSize };
  [self.view addSubnode:_textNode];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

@end
