/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASButtonNode.h"

#import <AsyncDisplayKit/ASThread.h>

@interface ASButtonNode ()
{
  ASDN::RecursiveMutex _propertyLock;
  
  NSAttributedString *_normalAttributedTitle;
  NSAttributedString *_highlightedAttributedTitle;
  NSAttributedString *_disabledAttributedTitle;
  
  UIImage *_normalImage;
  UIImage *_highlightedImage;
  UIImage *_disabledImage;
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
    
    [self addSubnode:_titleNode];
    [self addSubnode:_imageNode];
    
    [self addTarget:self action:@selector(controlEventUpdated:) forControlEvents:ASControlNodeEventAllEvents];
  }
  return self;
}

- (void)controlEventUpdated:(ASControlNode *)node
{
  [self updateImage];
  [self updateTitle];
}

- (void)updateImage
{
  ASDN::MutexLocker l(_propertyLock);
  
  UIImage *newImage;
  if (self.enabled == NO && _disabledImage) {
    newImage = _disabledImage;
  } else if (self.highlighted && _highlightedImage) {
    newImage = _highlightedImage;
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
  } else {
    newTitle = _normalAttributedTitle;
  }
  
  if (newTitle != self.titleNode.attributedString) {
    self.titleNode.attributedString = newTitle;
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

- (NSAttributedString *)attributedTitleForState:(ASButtonState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASButtonStateNormal:
      return _normalAttributedTitle;
      
    case ASButtonStateHighlighted:
      return _highlightedAttributedTitle;
      
    case ASButtonStateDisabled:
      return _disabledAttributedTitle;
  }
}

- (void)setAttributedTitle:(NSAttributedString *)title forState:(ASButtonState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASButtonStateNormal:
      _normalAttributedTitle = [title copy];
      break;
      
    case ASButtonStateHighlighted:
      _highlightedAttributedTitle = [title copy];
      break;
      
    case ASButtonStateDisabled:
      _disabledAttributedTitle = [title copy];
      break;
  }
  [self updateTitle];
}

- (UIImage *)imageForState:(ASButtonState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASButtonStateNormal:
      return _normalImage;
      
    case ASButtonStateHighlighted:
      return _highlightedImage;
      
    case ASButtonStateDisabled:
      return _disabledImage;
  }
}

- (void)setImage:(UIImage *)image forState:(ASButtonState)state
{
  ASDN::MutexLocker l(_propertyLock);
  switch (state) {
    case ASButtonStateNormal:
      _normalImage = image;
      break;
      
    case ASButtonStateHighlighted:
      _highlightedImage = image;
      break;
      
    case ASButtonStateDisabled:
      _disabledImage = image;
      break;
  }
  [self updateImage];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *stack = [[ASStackLayoutSpec alloc] init];
  stack.direction = self.laysOutHorizontally ? ASStackLayoutDirectionHorizontal : ASStackLayoutDirectionVertical;
  stack.spacing = self.contentSpacing;
  stack.justifyContent = ASStackLayoutJustifyContentCenter;
  stack.alignItems = ASStackLayoutAlignItemsCenter;
  
  NSMutableArray *children = [[NSMutableArray alloc] initWithCapacity:2];
  if (self.imageNode.image) {
    [children addObject:self.imageNode];
  }
  
  if (self.titleNode.attributedString.length > 0) {
    [children addObject:self.titleNode];
  }
  
  stack.children = children;
  
  return stack;
}

- (void)layout
{
  [super layout];
  self.imageNode.hidden = self.imageNode.image == nil;
  self.titleNode.hidden = self.titleNode.attributedString.length > 0 == NO;
}

@end
