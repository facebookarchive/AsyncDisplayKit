//
//  SupplementaryNode.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "SupplementaryNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutSpec.h>

static CGFloat kInsets = 15.0;

@interface SupplementaryNode ()
@property (nonatomic, strong) ASTextNode *textNode;
@end

@implementation SupplementaryNode

- (instancetype)initWithText:(NSString *)text
{
  self = [super init];
  if (self != nil) {
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedString = [[NSAttributedString alloc] initWithString:text
                                                                 attributes:[self textAttributes]];
    [self addSubnode:_textNode];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASCenterLayoutSpec *center = [[ASCenterLayoutSpec alloc] init];
  center.centeringOptions = ASCenterLayoutSpecCenteringXY;
  center.child = self.textNode;
  UIEdgeInsets insets = UIEdgeInsetsMake(kInsets, kInsets, kInsets, kInsets);
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:center];
}

#pragma mark - Text Formatting

- (NSDictionary *)textAttributes
{
  return @{
    NSFontAttributeName: [UIFont systemFontOfSize:18.0],
    NSForegroundColorAttributeName: [UIColor whiteColor],
  };
}

@end
