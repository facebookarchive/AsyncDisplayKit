//
//  ASButtonNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASButtonNode.h"
#import "ASStackLayoutSpec.h"
#import "ASThread.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASBackgroundLayoutSpec.h"
#import "ASInsetLayoutSpec.h"
#import "ASDisplayNode+Beta.h"
#import "ASStaticLayoutSpec.h"

@interface ASButtonNode ()
{
  ASDN::RecursiveMutex _propertyLock;
  
  NSAttributedString *_normalAttributedTitle;
  NSAttributedString *_highlightedAttributedTitle;
  NSAttributedString *_selectedAttributedTitle;
  NSAttributedString *_selectedHighlightedAttributedTitle;
  NSAttributedString *_disabledAttributedTitle;
  
  UIImage *_normalImage;
  UIImage *_highlightedImage;
  UIImage *_selectedImage;
  UIImage *_selectedHighlightedImage;
  UIImage *_disabledImage;

  UIImage *_normalBackgroundImage;
  UIImage *_highlightedBackgroundImage;
  UIImage *_selectedBackgroundImage;
  UIImage *_selectedHighlightedBackgroundImage;
  UIImage *_disabledBackgroundImage;
}

@end

@implementation ASButtonNode

@synthesize contentSpacing = _contentSpacing;
@synthesize laysOutHorizontally = _laysOutHorizontally;
@synthesize contentVerticalAlignment = _contentVerticalAlignment;
@synthesize contentHorizontalAlignment = _contentHorizontalAlignment;
@synthesize contentEdgeInsets = _contentEdgeInsets;
@synthesize titleNode = _titleNode;
@synthesize imageNode = _imageNode;
@synthesize backgroundImageNode = _backgroundImageNode;

- (instancetype)init
{
  if (self = [super init]) {
    self.usesImplicitHierarchyManagement = YES;
    
    _contentSpacing = 8.0;
    _laysOutHorizontally = YES;
    _contentHorizontalAlignment = ASHorizontalAlignmentMiddle;
    _contentVerticalAlignment = ASVerticalAlignmentCenter;
    _contentEdgeInsets = UIEdgeInsetsZero;
    self.accessibilityTraits = UIAccessibilityTraitButton;
  }
  return self;
}

- (ASTextNode *)titleNode
{
  if (!_titleNode) {
    _titleNode = [[ASTextNode alloc] init];
#if TARGET_OS_IOS 
      // tvOS needs access to the underlying view
      // of the button node to add a touch handler.
    [_titleNode setLayerBacked:YES];
#endif
    [_titleNode setFlexShrink:YES];
  }
  return _titleNode;
}

- (ASImageNode *)imageNode
{
  if (!_imageNode) {
    _imageNode = [[ASImageNode alloc] init];
    [_imageNode setLayerBacked:YES];
  }
  return _imageNode;
}

- (ASImageNode *)backgroundImageNode
{
  if (!_backgroundImageNode) {
    _backgroundImageNode = [[ASImageNode alloc] init];
    [_backgroundImageNode setLayerBacked:YES];
    [_backgroundImageNode setContentMode:UIViewContentModeScaleToFill];
  }
  return _backgroundImageNode;
}

- (void)setLayerBacked:(BOOL)layerBacked
{
  ASDisplayNodeAssert(!layerBacked, @"ASButtonNode must not be layer backed!");
  [super setLayerBacked:layerBacked];
}

- (void)setEnabled:(BOOL)enabled
{
  [super setEnabled:enabled];
  if (enabled) {
    self.accessibilityTraits = UIAccessibilityTraitButton;
  } else {
    self.accessibilityTraits = UIAccessibilityTraitButton | UIAccessibilityTraitNotEnabled;
  }
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
  [self.backgroundImageNode setDisplaysAsynchronously:displaysAsynchronously];
  [self.imageNode setDisplaysAsynchronously:displaysAsynchronously];
  [self.titleNode setDisplaysAsynchronously:displaysAsynchronously];
}

- (void)updateImage
{
  ASDN::MutexLocker l(_propertyLock);

  UIImage *newImage;
  if (self.enabled == NO && _disabledImage) {
    newImage = _disabledImage;
  } else if (self.highlighted && self.selected && _selectedHighlightedImage) {
    newImage = _selectedHighlightedImage;
  } else if (self.highlighted && _highlightedImage) {
    newImage = _highlightedImage;
  } else if (self.selected && _selectedImage) {
    newImage = _selectedImage;
  } else {
    newImage = _normalImage;
  }
  
  if ((_imageNode != nil || newImage != nil) && newImage != self.imageNode.image) {
    _imageNode.image = newImage;
    [self setNeedsLayout];
  }
}

- (void)updateTitle
{
  ASDN::MutexLocker l(_propertyLock);
  NSAttributedString *newTitle;
  if (self.enabled == NO && _disabledAttributedTitle) {
    newTitle = _disabledAttributedTitle;
  } else if (self.highlighted && self.selected && _selectedHighlightedAttributedTitle) {
    newTitle = _selectedHighlightedAttributedTitle;
  } else if (self.highlighted && _highlightedAttributedTitle) {
    newTitle = _highlightedAttributedTitle;
  } else if (self.selected && _selectedAttributedTitle) {
    newTitle = _selectedAttributedTitle;
  } else {
    newTitle = _normalAttributedTitle;
  }

  if ((_titleNode != nil || newTitle.length > 0) && newTitle != self.titleNode.attributedString) {
    _titleNode.attributedString = newTitle;
    self.accessibilityLabel = _titleNode.accessibilityLabel;
    [self setNeedsLayout];
  }
}

- (void)updateBackgroundImage
{
  ASDN::MutexLocker l(_propertyLock);
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledBackgroundImage) {
    newImage = _disabledBackgroundImage;
  } else if (self.highlighted && self.selected && _selectedHighlightedBackgroundImage) {
    newImage = _selectedHighlightedBackgroundImage;
  } else if (self.highlighted && _highlightedBackgroundImage) {
    newImage = _highlightedBackgroundImage;
  } else if (self.selected && _selectedBackgroundImage) {
    newImage = _selectedBackgroundImage;
  } else {
    newImage = _normalBackgroundImage;
  }
  
  if ((_backgroundImageNode != nil || newImage != nil) && newImage != self.backgroundImageNode.image) {
    _backgroundImageNode.image = newImage;
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

- (ASVerticalAlignment)contentVerticalAlignment
{
  ASDN::MutexLocker l(_propertyLock);
  return _contentVerticalAlignment;
}

- (void)setContentVerticalAlignment:(ASVerticalAlignment)contentVerticalAlignment
{
  ASDN::MutexLocker l(_propertyLock);
  _contentVerticalAlignment = contentVerticalAlignment;
}

- (ASHorizontalAlignment)contentHorizontalAlignment
{
  ASDN::MutexLocker l(_propertyLock);
  return _contentHorizontalAlignment;
}

- (void)setContentHorizontalAlignment:(ASHorizontalAlignment)contentHorizontalAlignment
{
  ASDN::MutexLocker l(_propertyLock);
  _contentHorizontalAlignment = contentHorizontalAlignment;
}

- (UIEdgeInsets)contentEdgeInsets
{
  ASDN::MutexLocker l(_propertyLock);
  return _contentEdgeInsets;
}

- (void)setContentEdgeInsets:(UIEdgeInsets)contentEdgeInsets
{
  ASDN::MutexLocker l(_propertyLock);
  _contentEdgeInsets = contentEdgeInsets;
}


#if TARGET_OS_IOS
- (void)setTitle:(NSString *)title withFont:(UIFont *)font withColor:(UIColor *)color forState:(ASControlState)state
{
  NSDictionary *attributes = @{
                               NSFontAttributeName: font ? : [UIFont systemFontOfSize:[UIFont buttonFontSize]],
                               NSForegroundColorAttributeName : color ? : [UIColor blackColor]
                               };
    
  NSAttributedString *string = [[NSAttributedString alloc] initWithString:title
                                                               attributes:attributes];
  [self setAttributedTitle:string forState:state];
}
#endif

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
        
    case ASControlStateSelected | ASControlStateHighlighted:
      return _selectedHighlightedAttributedTitle;
      
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
          
    case ASControlStateSelected | ASControlStateHighlighted:
      _selectedHighlightedAttributedTitle = [title copy];
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
      
    case ASControlStateSelected | ASControlStateHighlighted:
      return _selectedHighlightedImage;
          
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
    
    case ASControlStateSelected | ASControlStateHighlighted:
      _selectedHighlightedImage = image;
      break;
          
    case ASControlStateDisabled:
      _disabledImage = image;
      break;
      
    default:
      break;
  }
  [self updateImage];
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
    
    case ASControlStateSelected | ASControlStateHighlighted:
      return _selectedHighlightedBackgroundImage;
    
    case ASControlStateDisabled:
      return _disabledBackgroundImage;
    
    default:
      return _normalBackgroundImage;
  }
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
          
    case ASControlStateSelected | ASControlStateHighlighted:
      _selectedHighlightedBackgroundImage = image;
      break;
      
    case ASControlStateDisabled:
      _disabledBackgroundImage = image;
      break;
      
    default:
      break;
  }
  [self updateBackgroundImage];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  UIEdgeInsets contentEdgeInsets;
  ASLayoutSpec *spec;
  ASStackLayoutSpec *stack = [[ASStackLayoutSpec alloc] init];
  {
    ASDN::MutexLocker l(_propertyLock);
    stack.direction = _laysOutHorizontally ? ASStackLayoutDirectionHorizontal : ASStackLayoutDirectionVertical;
    stack.spacing = _contentSpacing;
    stack.horizontalAlignment = _contentHorizontalAlignment;
    stack.verticalAlignment = _contentVerticalAlignment;
    
    contentEdgeInsets = _contentEdgeInsets;
  }
  
  NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:2];
  if (_imageNode.image) {
    [children addObject:_imageNode];
  }
  
  if (_titleNode.attributedString.length > 0) {
    [children addObject:_titleNode];
  }
  
  stack.children = children;
  
  spec = stack;
  
  if (UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsetsZero, contentEdgeInsets) == NO) {
    spec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:contentEdgeInsets child:spec];
  }
  
  if (CGSizeEqualToSize(self.preferredFrameSize, CGSizeZero) == NO) {
    stack.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(self.preferredFrameSize);
    spec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[stack]];
  }
  
  if (_backgroundImageNode.image) {
    spec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:spec background:_backgroundImageNode];
  }
  
  return spec;
}

- (void)layout
{
  [super layout];
  _backgroundImageNode.hidden = (_backgroundImageNode.image == nil);
  _imageNode.hidden = (_imageNode.image == nil);
  _titleNode.hidden = (_titleNode.attributedString.length == 0);
}

@end
