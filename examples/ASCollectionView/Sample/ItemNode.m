//
//  ItemNode.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ItemNode.h"

@implementation ItemNode

- (instancetype)initWithString:(NSString *)string
{
  self = [super init];
  if (self != nil) {
    self.text = string;
    [self updateBackgroundColor];
  }
  return self;
}

- (void)updateBackgroundColor
{
  if (self.highlighted) {
    self.backgroundColor = [UIColor grayColor];
  } else if (self.selected) {
    self.backgroundColor = [UIColor darkGrayColor];
  } else {
    self.backgroundColor = [UIColor lightGrayColor];
  }
}

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  [self updateBackgroundColor];
}

- (void)setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  [self updateBackgroundColor];
}

@end
