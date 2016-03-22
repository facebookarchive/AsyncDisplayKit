//
//  ColorNode.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ColorNode.h"
#import "ASLayoutableInspectorNode.h"

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
    [self addTarget:self action:@selector(nodeWasTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  
  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  return CGSizeMake(50, 50);
}

- (void)nodeWasTapped:(UIGestureRecognizer *)sender
{
  [ASLayoutableInspectorNode sharedInstance].layoutableToEdit = self;
}

@end
