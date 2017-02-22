//
//  ASTextFieldView.m
//  AsyncDisplayKit
//
//  Created by Kyle Shank on 2/14/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTextFieldView.h"

@implementation ASTextFieldView {
  UIEdgeInsets _textContainerInset;
}

-(UIEdgeInsets)textContainerInset {
  return _textContainerInset;
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
  BOOL needsUpdate = !UIEdgeInsetsEqualToEdgeInsets(textContainerInset, _textContainerInset);
  if (needsUpdate) {
    _textContainerInset = textContainerInset;
    [self setNeedsLayout];
  }
}

- (CGRect)textRectForBounds:(CGRect)bounds{
  return CGRectMake(
                    bounds.origin.x + _textContainerInset.left,
                    bounds.origin.y + _textContainerInset.top,
                    bounds.size.width - _textContainerInset.left - _textContainerInset.right,
                    bounds.size.height - _textContainerInset.top - _textContainerInset.bottom);
}

-(CGRect) editingRectForBounds:(CGRect)bounds{
  return [self textRectForBounds:bounds];
}

@end
