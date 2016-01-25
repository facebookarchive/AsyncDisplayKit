/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASButtonNode.h"
#import "ASStackLayoutSpec.h"
#import "ASThread.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASBackgroundLayoutSpec.h"

@interface ASButtonNode ()
{
  ASDN::RecursiveMutex _propertyLock;
  
  NSAttributedString *_normalAttributedTitle;
  NSAttributedString *_highlightedAttributedTitle;
  NSAttributedString *_selectedAttributedTitle;
  NSAttributedString *_disabledAttributedTitle;
  
  UIImage *_normalImage;
  UIImage *_highlightedImage;
  UIImage *_selectedImage;
  UIImage *_disabledImage;

  UIImage *_normalBackgroundImage;
  UIImage *_highlightedBackgroundImage;
  UIImage *_selectedBackgroundImage;
  UIImage *_disabledBackgroundImage;
}

@end

@implementation ASButtonNode

@synthesize contentSpacing = _contentSpacing;
@synthesize laysOutHorizontally = _laysOutHorizontally;

- (instancetype)init
{
  if (self = [super init]) {    
    _contentSpacing = 8.0;
    _laysOutHorizontally = YES;

    _titleNode = [[ASTextNode alloc] init];
    _imageNode = [[ASImageNode alloc] init];
    _backgroundImageNode = [[ASImageNode alloc] init];
    [_backgroundImageNode setContentMode:UIViewContentModeScaleToFill];
    
    [_titleNode setLayerBacked:YES];
    [_imageNode setLayerBacked:YES];
    [_backgroundImageNode setLayerBacked:YES];
      
    _contentHorizontalAlignment = ASAlignmentMiddle;
    _contentVerticalAlignment = ASAlignmentCenter;
    
    [self addSubnode:_backgroundImageNode];
    [self addSubnode:_titleNode];
    [self addSubnode:_imageNode];
  }
  return self;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  ASDisplayNodeAssert(!layerBacked, @"ASButtonNode must not be layer backed!");
  [super setLayerBacked:layerBacked];
}

- (void)setEnabled:(BOOL)enabled
{
  [super setEnabled:enabled];
  [self updateButtonContent];
}

- (void)setHighlighted:(BOOL)highlighted
{
  [super setHighlighted:highlighted];
  [self updateButtonContent];
}

- (void)setSelected:(BOOL)selected
{
  [super setSelected:selected];
  [self updateButtonContent];
}

- (void)updateButtonContent
{
  [self updateBackgroundImage];
  [self updateImage];
  [self updateTitle];
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously
{
  [super setDisplaysAsynchronously:displaysAsynchronously];
  [self.imageNode setDisplaysAsynchronously:displaysAsynchronously];
  [self.titleNode setDisplaysAsynchronously:displaysAsynchronously];
}

- (void)updateImage
{
  ASDN::MutexLocker l(_propertyLock);
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledImage) {
    newImage = _disabledImage;
  } else if (self.highlighted && _highlightedImage) {
    newImage = _highlightedImage;
  } else if (self.selected && _selectedImage) {
    newImage = _selectedImage;
  } else {
    newImage = _normalImage;
  }
  
  if (newImage != self.imageNode.image) {
    self.imageNode.image = newImage;
    [self setNeedsLayout];
  }
}

- (void)updateTitle
{
  ASDN::MutexLocker l(_propertyLock);
  NSAttributedString *newTitle;
  if (self.enabled == NO && _disabledAttributedTitle) {
    newTitle = _disabledAttributedTitle;
  } else if (self.highlighted && _highlightedAttributedTitle) {
    newTitle = _highlightedAttributedTitle;
  } else if (self.selected && _selectedAttributedTitle) {
    newTitle = _selectedAttributedTitle;
  } else {
    newTitle = _normalAttributedTitle;
  }
  
  if (newTitle != self.titleNode.attributedString) {
    self.titleNode.attributedString = newTitle;
    [self setNeedsLayout];
  }
}

- (void)updateBackgroundImage
{
  ASDN::MutexLocker l(_propertyLock);
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledBackgroundImage) {
    newImage = _disabledBackgroundImage;
  } else if (self.highlighted && _highlightedBackgroundImage) {
    newImage = _highlightedBackgroundImage;
  } else if (self.selected && _selectedBackgroundImage) {
    newImage = _selectedBackgroundImage;
  } else {
    newImage = _normalBackgroundImage;
  }
  
  if (newImage != self.backgroundImageNode.image) {
    self.backgroundImageNode.image = newImage;
    [self setNeedsLayout];
  }
}

- (CGFloat)contentSpacing
{
  ASDN::MutexLocker l(_propertyLock);
  return _contentSpacing;
}

- (void)setContentSpacing:(CGFloat)contentSpacing
{
  ASDN::MutexLocker l(_propertyLock);
  if (contentSpacing == _contentSpacing)
    return;
  
  _contentSpacing = contentSpacing;
  [self setNeedsLayout];
}

- (BOOL)laysOutHorizontally
{
  ASDN::MutexLocker l(_propertyLock);
  return _laysOutHorizontally;
}

- (void)setLaysOutHorizontally:(BOOL)laysOutHorizontally
{
  ASDN::MutexLocker l(_propertyLock);
  if (laysOutHorizontally == _laysOutHorizontally)
    return;
  
  _laysOutHorizontally = laysOutHorizontally;
  [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title withFont:(UIFont *)font withColor:(UIColor *)color forState:(ASControlState)state
{
  NSDictionary *attributes = @{
                               NSFontAttributeName: font ? font :[UIFont systemFontOfSize:[UIFont buttonFontSize]],
                               NSForegroundColorAttributeName : color ? color : [UIColor blackColor]
                               };
    
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:title
                                                               attributes:attributes];
  [self setAttributedTitle:string forState:state];
}

- (NSAttributedString *)attributedTitleForState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      return _normalAttributedTitle;
      
    case ASControlStateHighlighted:
      return _highlightedAttributedTitle;
      
    case ASControlStateSelected:
      return _selectedAttributedTitle;
      
    case ASControlStateDisabled:
      return _disabledAttributedTitle;
          
    default:
      return _normalAttributedTitle;
  }
}

- (void)setAttributedTitle:(NSAttributedString *)title forState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      _normalAttributedTitle = [title copy];
      break;
      
    case ASControlStateHighlighted:
      _highlightedAttributedTitle = [title copy];
      break;
      
    case ASControlStateSelected:
      _selectedAttributedTitle = [title copy];
      break;
      
    case ASControlStateDisabled:
      _disabledAttributedTitle = [title copy];
      break;
      
    default:
      break;
  }
  [self updateTitle];
}

- (UIImage *)imageForState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      return _normalImage;
      
    case ASControlStateHighlighted:
      return _highlightedImage;
      
    case ASControlStateSelected:
      return _selectedImage;
      
    case ASControlStateDisabled:
      return _disabledImage;
      
    default:
      return _normalImage;
  }
}

- (void)setImage:(UIImage *)image forState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      _normalImage = image;
      break;
      
    case ASControlStateHighlighted:
      _highlightedImage = image;
      break;
      
    case ASControlStateSelected:
      _selectedImage = image;
      break;
      
    case ASControlStateDisabled:
      _disabledImage = image;
      break;
      
    default:
      break;
  }
  [self updateImage];
}

- (void)setBackgroundImage:(UIImage *)image forState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      _normalBackgroundImage = image;
      break;
      
    case ASControlStateHighlighted:
      _highlightedBackgroundImage = image;
      break;
      
    case ASControlStateSelected:
      _selectedBackgroundImage = image;
      break;
      
    case ASControlStateDisabled:
      _disabledBackgroundImage = image;
      break;
      
    default:
      break;
  }
  [self updateBackgroundImage];
}

- (UIImage *)backgroundImageForState:(ASControlState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASControlStateNormal:
      return _normalBackgroundImage;
      
    case ASControlStateHighlighted:
      return _highlightedBackgroundImage;
      
    case ASControlStateSelected:
      return _selectedBackgroundImage;
      
    case ASControlStateDisabled:
      return _disabledBackgroundImage;
      
    default:
      return _normalBackgroundImage;
  }

}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *stack = [[ASStackLayoutSpec alloc] init];
  stack.direction = self.laysOutHorizontally ? ASStackLayoutDirectionHorizontal : ASStackLayoutDirectionVertical;
  stack.spacing = self.contentSpacing;
  stack.horizontalAlignment = _contentHorizontalAlignment;
  stack.verticalAlignment = _contentVerticalAlignment;
  
  NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:2];
  if (self.imageNode.image) {
    [children addObject:self.imageNode];
  }
  
  if (self.titleNode.attributedString.length > 0) {
    [children addObject:self.titleNode];
  }
  
  stack.children = children;
  
  if (self.backgroundImageNode.image) {
      return [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:stack
                                                        background:self.backgroundImageNode];
  } else {
      return stack;
  }
}

- (void)layout
{
  [super layout];
  self.backgroundImageNode.hidden = self.backgroundImageNode.image == nil;
  self.imageNode.hidden = self.imageNode.image == nil;
  self.titleNode.hidden = self.titleNode.attributedString.length > 0 == NO;
}

@end
