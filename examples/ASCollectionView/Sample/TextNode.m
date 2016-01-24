//
//  TextNode.m
//  Sample
//
//  Created by Nikita Ivanchikov on 12/8/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "TextNode.h"

@interface TextNode()
{
  ASTextNode *_textNode;
}

@end


@implementation TextNode

- (instancetype)initWithString:(NSString *)string verticalTextAlignment: (ASTextNodeVerticalTextAlignment) verticalAlignment
{
  if (self = [super init]) {
    self.backgroundColor = [UIColor lightGrayColor];
    
    _textNode = [ASTextNode new];
    _textNode.verticalTextAlignment = verticalAlignment;
    _textNode.attributedString = [[NSAttributedString alloc] initWithString:string
                                                                 attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:18.0]}];
    [self addSubnode:_textNode];
  }
  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  CGSize size = [_textNode measure:constrainedSize];
  return CGSizeMake(constrainedSize.width, size.height + 20.0f);
}

- (void)layout
{
  _textNode.frame = self.bounds;
}

@end
