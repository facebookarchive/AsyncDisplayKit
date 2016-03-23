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
  ASTextNode      *_textNode1;
  ASTextNode      *_textNode2;
  ASTextNode      *_textNode3;
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
    _textNode1 = [[ASTextNode alloc] init];
    _textNode1.attributedString = [[NSAttributedString alloc] initWithString:@"test"];
    _textNode1.backgroundColor = [UIColor greenColor];
    _textNode1.userInteractionEnabled = YES;
    [_textNode1 addTarget:self action:@selector(textTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _textNode2 = [[ASTextNode alloc] init];
    _textNode2.attributedString = [[NSAttributedString alloc] initWithString:@"Hhhhhhhhhheeeeeeeeeelllllloooooooo"];
    _textNode2.backgroundColor = [UIColor greenColor];
    _textNode2.userInteractionEnabled = YES;
    [_textNode2 addTarget:self action:@selector(textTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _textNode3 = [[ASTextNode alloc] init];
    _textNode3.attributedString = [[NSAttributedString alloc] initWithString:@"another test text node"];
    _textNode3.backgroundColor = [UIColor greenColor];
    _textNode3.userInteractionEnabled = YES;
    [_textNode3 addTarget:self action:@selector(textTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
  }
  
  return self;
}

- (void)textTapped:(UIGestureRecognizer *)sender
{
  [ASLayoutableInspectorNode sharedInstance].layoutableToEdit = (ASTextNode *)sender;
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
  
  [children addObject:_textNode1];
  [children addObject:_textNode2];
  [children addObject:_textNode3];
  
  _textNode1.flexShrink = YES;
  _textNode2.flexShrink = YES;
  _textNode3.flexShrink = YES;

  ASStackLayoutSpec *innerStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  innerStack.children = children;
  innerStack.flexGrow = YES;
  innerStack.flexShrink = YES;

//  _individualColorNode.preferredFrameSize = CGSizeMake(100, 600);
  _individualColorNode.flexGrow = YES;
  _individualColorNode.flexShrink = YES;
  
  ASStackLayoutSpec *outerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  outerStack.flexGrow = YES;
  outerStack.flexShrink = YES;
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
