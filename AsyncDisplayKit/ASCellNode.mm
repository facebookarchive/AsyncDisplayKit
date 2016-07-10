//
//  ASCellNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASCellNode+Internal.h"

#import "ASEqualityHelpers.h"
#import "ASDisplayNodeInternal.h"
#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASTextNode.h>

#import <AsyncDisplayKit/ASViewController.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

#pragma mark -
#pragma mark ASCellNode

@interface ASCellNode ()
{
  ASDisplayNodeViewControllerBlock _viewControllerBlock;
  ASDisplayNodeDidLoadBlock _viewControllerDidLoadBlock;
  ASDisplayNode *_viewControllerNode;
  UIViewController *_viewController;
  BOOL _suspendInteractionDelegate;
}

@end

@implementation ASCellNode
@synthesize interactionDelegate = _interactionDelegate;

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  // Use UITableViewCell defaults
  _selectionStyle = UITableViewCellSelectionStyleDefault;
  self.clipsToBounds = YES;
  return self;
}

- (instancetype)initWithViewControllerBlock:(ASDisplayNodeViewControllerBlock)viewControllerBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  if (!(self = [super init]))
    return nil;
  
  ASDisplayNodeAssertNotNil(viewControllerBlock, @"should initialize with a valid block that returns a UIViewController");
  _viewControllerBlock = viewControllerBlock;
  _viewControllerDidLoadBlock = didLoadBlock;

  return self;
}

- (void)didLoad
{
  [super didLoad];

  if (_viewControllerBlock != nil) {

    _viewController = _viewControllerBlock();
    _viewControllerBlock = nil;

    if ([_viewController isKindOfClass:[ASViewController class]]) {
      ASViewController *asViewController = (ASViewController *)_viewController;
      _viewControllerNode = asViewController.node;
      [_viewController view];
    } else {
      _viewControllerNode = [[ASDisplayNode alloc] initWithViewBlock:^{
        return _viewController.view;
      }];
    }
    [self addSubnode:_viewControllerNode];

    // Since we just loaded our node, and added _viewControllerNode as a subnode,
    // _viewControllerNode must have just loaded its view, so now is an appropriate
    // time to execute our didLoadBlock, if we were given one.
    if (_viewControllerDidLoadBlock != nil) {
      _viewControllerDidLoadBlock(self);
      _viewControllerDidLoadBlock = nil;
    }
  }
}

- (void)layout
{
  [super layout];
  
  _viewControllerNode.frame = self.bounds;
}

- (void)layoutDidFinish
{
  [super layoutDidFinish];

  _viewControllerNode.frame = self.bounds;
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

- (void)__setNeedsLayout
{
  CGSize oldSize = self.calculatedSize;
  [super __setNeedsLayout];
  
  //Adding this lock because lock used to be held when this method was called. Not sure if it's necessary for
  //didRelayoutFromOldSize:toNewSize:
  ASDN::MutexLocker l(_propertyLock);
  [self didRelayoutFromOldSize:oldSize toNewSize:self.calculatedSize];
}

- (void)transitionLayoutWithAnimation:(BOOL)animated
                         shouldMeasureAsync:(BOOL)shouldMeasureAsync
                      measurementCompletion:(void(^)())completion
{
  CGSize oldSize = self.calculatedSize;
  [super transitionLayoutWithAnimation:animated
                    shouldMeasureAsync:shouldMeasureAsync
                 measurementCompletion:^{
                   [self didRelayoutFromOldSize:oldSize toNewSize:self.calculatedSize];
                   if (completion) {
                     completion();
                   }
                 }
   ];
}

- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  CGSize oldSize = self.calculatedSize;
  [super transitionLayoutWithSizeRange:constrainedSize
                              animated:animated
                    shouldMeasureAsync:shouldMeasureAsync
                 measurementCompletion:^{
                   [self didRelayoutFromOldSize:oldSize toNewSize:self.calculatedSize];
                   if (completion) {
                     completion();
                   }
                 }
   ];
}

- (void)didRelayoutFromOldSize:(CGSize)oldSize toNewSize:(CGSize)newSize
{
  if (_interactionDelegate != nil) {
    ASPerformBlockOnMainThread(^{
      BOOL sizeChanged = !CGSizeEqualToSize(oldSize, newSize);
      [_interactionDelegate nodeDidRelayout:self sizeChanged:sizeChanged];
    });
  }
}

- (void)setSelected:(BOOL)selected
{
  if (_selected != selected) {
    _selected = selected;
    if (!_suspendInteractionDelegate) {
      [_interactionDelegate nodeSelectedStateDidChange:self];
    }
  }
}

- (void)setHighlighted:(BOOL)highlighted
{
  if (_highlighted != highlighted) {
    _highlighted = highlighted;
    if (!_suspendInteractionDelegate) {
      [_interactionDelegate nodeHighlightedStateDidChange:self];
    }
  }
}

- (void)__setSelectedFromUIKit:(BOOL)selected;
{
  if (selected != _selected) {
    _suspendInteractionDelegate = YES;
    self.selected = selected;
    _suspendInteractionDelegate = NO;
  }
}

- (void)__setHighlightedFromUIKit:(BOOL)highlighted;
{
  if (highlighted != _highlighted) {
    _suspendInteractionDelegate = YES;
    self.highlighted = highlighted;
    _suspendInteractionDelegate = NO;
  }
}

- (BOOL)selected
{
  return self.isSelected;
}

- (BOOL)highlighted
{
  return self.isSelected;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"

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

#pragma clang diagnostic pop

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
  // To be overriden by subclasses
}

- (void)cellNodeVisibilityEvent:(ASCellNodeVisibilityEvent)event inScrollView:(UIScrollView *)scrollView withCellFrame:(CGRect)cellFrame
{
  // To be overriden by subclasses
}

- (void)visibleStateDidChange:(BOOL)isVisible
{
  [super visibleStateDidChange:isVisible];
  
  CGRect cellFrame = CGRectZero;
  if (_scrollView) {
    // It is not safe to message nil with a structure return value, so ensure our _scrollView has not died.
    cellFrame = [self.view convertRect:self.bounds toView:_scrollView];
  }
  [self cellNodeVisibilityEvent:isVisible ? ASCellNodeVisibilityEventVisible : ASCellNodeVisibilityEventInvisible
                   inScrollView:_scrollView
                  withCellFrame:cellFrame];
}

@end


#pragma mark -
#pragma mark ASTextCellNode

@interface ASTextCellNode ()

@property (nonatomic, strong) ASTextNode *textNode;

@end


@implementation ASTextCellNode

static const CGFloat kASTextCellNodeDefaultFontSize = 18.0f;
static const CGFloat kASTextCellNodeDefaultHorizontalPadding = 15.0f;
static const CGFloat kASTextCellNodeDefaultVerticalPadding = 11.0f;

- (instancetype)init
{
  return [self initWithAttributes:[self defaultTextAttributes] insets:[self defaultTextInsets]];
}

- (instancetype)initWithAttributes:(NSDictionary *)textAttributes insets:(UIEdgeInsets)textInsets
{
  self = [super init];
  if (self) {
    _textInsets = textInsets;
    _textAttributes = [textAttributes copy];
    _textNode = [[ASTextNode alloc] init];
    [self addSubnode:_textNode];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:self.textInsets child:self.textNode];
}

- (NSDictionary *)defaultTextAttributes
{
  return @{NSFontAttributeName : [UIFont systemFontOfSize:kASTextCellNodeDefaultFontSize]};
}

- (UIEdgeInsets)defaultTextInsets
{
    return UIEdgeInsetsMake(kASTextCellNodeDefaultVerticalPadding, kASTextCellNodeDefaultHorizontalPadding, kASTextCellNodeDefaultVerticalPadding, kASTextCellNodeDefaultHorizontalPadding);
}

- (void)setTextAttributes:(NSDictionary *)textAttributes
{
  ASDisplayNodeAssertNotNil(textAttributes, @"Invalid text attributes");
  
  _textAttributes = [textAttributes copy];
  
  [self updateAttributedString];
}

- (void)setTextInsets:(UIEdgeInsets)textInsets
{
  _textInsets = textInsets;

  [self updateAttributedString];
}

- (void)setText:(NSString *)text
{
  if (ASObjectIsEqual(_text, text)) return;

  _text = [text copy];
  
  [self updateAttributedString];
}

- (void)updateAttributedString
{
  if (_text == nil) {
    _textNode.attributedString = nil;
    return;
  }
  
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:self.text attributes:self.textAttributes];
  [self setNeedsLayout];
}

@end
