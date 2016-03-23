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
#import "ASLayoutableInspectorNode.h"

@implementation PlaygroundNode
{
  NSArray         *_colorNodes;
  ASDisplayNode   *_individualColorNode;
  ASTextNode      *_textNode;
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
    
    // user interaction off by default
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedString = [[NSAttributedString alloc] initWithString:@"Hhhhhhhhhheeeeeeeeeelllllloooooooo"];
    _textNode.backgroundColor = [UIColor greenColor];
    _textNode.userInteractionEnabled = YES;
    [_textNode addTarget:self action:@selector(textTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  
  return self;
}

- (void)textTapped:(UIGestureRecognizer *)sender
{
  [ASLayoutableInspectorNode sharedInstance].layoutableToEdit = _textNode;
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
  
  _textNode.flexShrink = YES;
  _textNode.flexGrow = YES;
  _textNode.alignSelf = ASStackLayoutAlignSelfStretch;
  [children addObject:_textNode];
  
  ASStackLayoutSpec *innerStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  innerStack.children = children;
  innerStack.flexGrow = YES;

  _individualColorNode.preferredFrameSize = CGSizeMake(100, 600);
  ASStackLayoutSpec *outerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  outerStack.flexGrow = YES;
  outerStack.children = @[innerStack, _individualColorNode];
  outerStack.alignItems = ASStackLayoutAlignItemsStretch;
  
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
