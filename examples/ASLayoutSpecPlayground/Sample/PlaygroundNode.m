//
//  PlaygroundNode.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PlaygroundNode.h"
#import "ColorNode.h"
#import "AsyncDisplayKit+Debug.h"

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
  
    self.usesImplicitHierarchyManagement = YES;
//    self.clipsToBounds = YES;                   // make outside bounds semi-transparent
    
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
    node.flexGrow = YES;
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:node];
    insetSpec.flexGrow = YES;
    [children addObject:insetSpec];
  }
  ASStackLayoutSpec *innerStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  innerStack.children = children;
  innerStack.flexGrow = YES;

  ASStackLayoutSpec *outerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  outerStack.flexGrow = YES;
  outerStack.children = @[innerStack, _individualColorNode];
  
  return outerStack;
}

//- (ASSizeRange)playgroundConstrainedSize
//{
//  if (ASRangeIsEmpty(_playgroundConstrainedSize)) {
//    CGSize maxSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
//    _playgroundConstrainedSize = ASSizeRangeMake(maxSize, maxSize);
//  }
//  return _playgroundConstrainedSize;
//}
//
//- (ASSizeRange)nodeConstrainedSize
//{
//  return self.playgroundConstrainedSize;
//}

@end
