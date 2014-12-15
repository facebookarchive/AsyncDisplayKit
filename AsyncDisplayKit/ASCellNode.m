/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCellNode.h"

#import "ASDisplayNode+Subclasses.h"
#import "ASTextNode.h"


#pragma mark -
#pragma mark ASCellNode

@implementation ASCellNode

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // use UITableViewCell defaults
  _selectionStyle = UITableViewCellSelectionStyleDefault;

  return self;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  // ASRangeController expects ASCellNodes to be view-backed.  (Layer-backing is supported on ASCellNode subnodes.)
  ASDisplayNodeAssert(!layerBacked, @"ASCellNode does not support layer-backing.");
}

@end


#pragma mark -
#pragma mark ASTextCellNode

@interface ASTextCellNode () {
  NSString *_text;
  ASTextNode *_textNode;
}

@end


@implementation ASTextCellNode

static const CGFloat kHorizontalPadding = 15.0f;
static const CGFloat kVerticalPadding = 11.0f;
static const CGFloat kFontSize = 18.0f;

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _textNode = [[ASTextNode alloc] init];
  [self addSubnode:_textNode];

  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  CGSize availableSize = CGSizeMake(constrainedSize.width - 2 * kHorizontalPadding,
                                    constrainedSize.height - 2 * kVerticalPadding);
  CGSize textNodeSize = [_textNode measure:availableSize];

  return CGSizeMake(ceilf(2 * kHorizontalPadding + textNodeSize.width),
                    ceilf(2 * kVerticalPadding + textNodeSize.height));
}

- (void)layout
{
  _textNode.frame = CGRectInset(self.bounds, kHorizontalPadding, kVerticalPadding);
}

- (void)setText:(NSString *)text
{
  if (_text == text)
    return;

  _text = [text copy];
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:_text
                                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:kFontSize]}];

  [self invalidateCalculatedSize];
}

@end
