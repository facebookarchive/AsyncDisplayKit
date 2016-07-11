//
//  NSMutableAttributedString+TextKitAdditions.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "NSMutableAttributedString+TextKitAdditions.h"

@implementation NSMutableAttributedString (TextKitAdditions)

#pragma mark - Convenience Methods

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight
{
  if (range.length) {

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setMinimumLineHeight:minimumLineHeight];
    [self attributeTextInRange:range withTextKitParagraphStyle:style];
  }
}

- (void)attributeTextInRange:(NSRange)range withTextKitMinimumLineHeight:(CGFloat)minimumLineHeight maximumLineHeight:(CGFloat)maximumLineHeight
{
  if (range.length) {

    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setMinimumLineHeight:minimumLineHeight];
    [style setMaximumLineHeight:maximumLineHeight];
    [self attributeTextInRange:range withTextKitParagraphStyle:style];
  }
}

- (void)attributeTextInRange:(NSRange)range withTextKitLineHeight:(CGFloat)lineHeight
{
  [self attributeTextInRange:range withTextKitMinimumLineHeight:lineHeight maximumLineHeight:lineHeight];
}

- (void)attributeTextInRange:(NSRange)range withTextKitParagraphStyle:(NSParagraphStyle *)paragraphStyle
{
  if (range.length) {
    [self addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:range];
  }
}

@end
