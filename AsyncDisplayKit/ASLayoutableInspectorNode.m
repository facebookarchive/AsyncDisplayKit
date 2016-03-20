//
//  EditorNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "EditorNode.h"

@implementation EditorNode
{
  ASTextNode *_textNode;
}

- (void)setLayoutableToEdit:(id<ASLayoutable>)layoutableToEdit
{
  if (_layoutableToEdit != layoutableToEdit) {
    _layoutableToEdit = layoutableToEdit;
    _textNode.attributedString = [self attributedStringFromLayout:_layoutableToEdit];
    self.backgroundColor = [UIColor colorWithRed:40/255.0 green:43/255.0 blue:53/255.0 alpha:1.0];
  }
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.usesImplicitHierarchyManagement = YES;
    _textNode = [[ASTextNode alloc] init];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10) child:_textNode];
  return insetSpec;
}

- (NSAttributedString *)attributedStringFromLayout:(id<ASLayoutable>)layoutable
{
  NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor whiteColor],
                               NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular" size:12]};
  return [[NSAttributedString alloc] initWithString:[layoutable asciiArtString] attributes:attributes];
}

@end
