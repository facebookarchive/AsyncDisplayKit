//
//  PlaygroundContainerNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "PlaygroundContainerNode.h"
#import "PlaygroundNode.h"
#import "EditorNode.h"

@implementation PlaygroundContainerNode
{
  EditorNode *_editorNode;
  PlaygroundNode *_playgroundNode;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.usesImplicitHierarchyManagement = YES;
    _editorNode = [[EditorNode alloc] init];
    _editorNode.flexBasis = ASRelativeDimensionMakeWithPercent(1.0);
    
    _playgroundNode = [[PlaygroundNode alloc] init];
  }
  return self;
}


- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *verticalStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.children = @[_playgroundNode, _editorNode];
  verticalStack.horizontalAlignment = ASAlignmentMiddle;
  
  _editorNode.layoutableToEdit = verticalStack;
  
  return verticalStack;  
}

@end
