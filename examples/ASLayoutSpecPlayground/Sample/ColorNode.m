//
//  ColorNode.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ColorNode.h"

@implementation ColorNode
{
  ASTextNode    *_cellNumber;
  ASButtonNode  *_plusSignButton;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  
  if (self) {
  
    self.layer.borderWidth = 2;
    self.layer.borderColor = [[UIColor blackColor] CGColor];
    self.backgroundColor = [UIColor purpleColor];
    self.alignSelf = ASStackLayoutAlignSelfEnd;
  }
  
  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  return CGSizeMake(100, 100);
}

@end
