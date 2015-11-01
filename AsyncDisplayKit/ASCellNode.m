/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASCellNode.h"

#import "ASInternalHelpers.h"
#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASTextNode.h>

#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

#pragma mark -
#pragma mark ASCellNode

@implementation ASCellNode

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // use UITableViewCell defaults
  _selectionStyle = UITableViewCellSelectionStyleDefault;
  self.clipsToBounds = YES;
  _relayoutAnimation = UITableViewRowAnimationAutomatic;

  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  // ASRangeController expects ASCellNodes to be view-backed.  (Layer-backing is supported on ASCellNode subnodes.)
  ASDisplayNodeAssert(!layerBacked, @"ASCellNode does not support layer-backing.");
}

- (void)setNeedsLayout
{
  ASDisplayNodeAssertThreadAffinity(self);  
  [super setNeedsLayout];
  
  if (_layoutDelegate != nil) {
    ASPerformBlockOnMainThread(^{
      [_layoutDelegate node:self didRelayoutWithSuggestedAnimation:_relayoutAnimation];
    });
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self.view isKindOfClass:_ASDisplayView.class], @"ASCellNode views must be of type _ASDisplayView");
  [(_ASDisplayView *)self.view __forwardTouchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self.view isKindOfClass:_ASDisplayView.class], @"ASCellNode views must be of type _ASDisplayView");
  [(_ASDisplayView *)self.view __forwardTouchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self.view isKindOfClass:_ASDisplayView.class], @"ASCellNode views must be of type _ASDisplayView");
  [(_ASDisplayView *)self.view __forwardTouchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self.view isKindOfClass:_ASDisplayView.class], @"ASCellNode views must be of type _ASDisplayView");
  [(_ASDisplayView *)self.view __forwardTouchesCancelled:touches withEvent:event];
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

static const CGFloat kFontSize = 18.0f;

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _textNode = [[ASTextNode alloc] init];
  [self addSubnode:_textNode];

  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  static const CGFloat kHorizontalPadding = 15.0f;
  static const CGFloat kVerticalPadding = 11.0f;
  UIEdgeInsets insets = UIEdgeInsetsMake(kVerticalPadding, kHorizontalPadding, kVerticalPadding, kHorizontalPadding);
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_textNode];
}

- (void)setText:(NSString *)text
{
  if (_text == text)
    return;

  _text = [text copy];
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:_text
                                                               attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:kFontSize]}];
  [self setNeedsLayout];
}

@end
