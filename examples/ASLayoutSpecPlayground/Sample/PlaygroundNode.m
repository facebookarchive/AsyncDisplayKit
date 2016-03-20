//
//  PlaygroundNode.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PlaygroundNode.h"
#import "ColorNode.h"


@implementation PlaygroundNode
{
  NSArray         *_colorNodes;
  ASDisplayNode   *_individualColorNode;
}
#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  
  if (self) {
  
    self.backgroundColor = [UIColor lightGrayColor];
    self.usesImplicitHierarchyManagement = YES;
    
    ColorNode *node = [[ColorNode alloc] init];
    ColorNode *node2 = [[ColorNode alloc] init];
    ColorNode *node3 = [[ColorNode alloc] init];
    _colorNodes = @[node, node2, node3];

    _individualColorNode = [[ColorNode alloc] init];
    _individualColorNode.backgroundColor = [UIColor orangeColor];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  NSMutableArray *children = [[NSMutableArray alloc] init];
  for (ASDisplayNode *node in _colorNodes) {
    UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:node];
    [children addObject:insetSpec];
  }
  ASStackLayoutSpec *innerStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  innerStack.children = children;
  
  ASStackLayoutSpec *outerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  outerStack.children = @[innerStack, _individualColorNode];
  
  return outerStack;
}

@end
