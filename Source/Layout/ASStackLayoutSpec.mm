//
//  ASStackLayoutSpec.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASStackLayoutSpec.h>

#import <numeric>
#import <vector>

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASLayoutElement.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>
#import <AsyncDisplayKit/ASLayoutSpecUtilities.h>
#import <AsyncDisplayKit/ASStackPositionedLayout.h>
#import <AsyncDisplayKit/ASStackUnpositionedLayout.h>

@implementation ASStackLayoutSpec

- (instancetype)init
{
  return [self initWithDirection:ASStackLayoutDirectionHorizontal spacing:0.0 justifyContent:ASStackLayoutJustifyContentStart alignItems:ASStackLayoutAlignItemsStretch flexWrap:ASStackLayoutFlexWrapNoWrap alignContent:ASStackLayoutAlignContentStart children:nil];
}

+ (instancetype)stackLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems children:(NSArray *)children
{
  return [[self alloc] initWithDirection:direction spacing:spacing justifyContent:justifyContent alignItems:alignItems flexWrap:ASStackLayoutFlexWrapNoWrap alignContent:ASStackLayoutAlignContentStart children:children];
}

+ (instancetype)stackLayoutSpecWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems flexWrap:(ASStackLayoutFlexWrap)flexWrap alignContent:(ASStackLayoutAlignContent)alignContent children:(NSArray<id<ASLayoutElement>> *)children
{
  return [[self alloc] initWithDirection:direction spacing:spacing justifyContent:justifyContent alignItems:alignItems flexWrap:flexWrap alignContent:alignContent children:children];
}

+ (instancetype)verticalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.direction = ASStackLayoutDirectionVertical;
  return stackLayoutSpec;
}

+ (instancetype)horizontalStackLayoutSpec
{
  ASStackLayoutSpec *stackLayoutSpec = [[self alloc] init];
  stackLayoutSpec.direction = ASStackLayoutDirectionHorizontal;
  return stackLayoutSpec;
}

- (instancetype)initWithDirection:(ASStackLayoutDirection)direction spacing:(CGFloat)spacing justifyContent:(ASStackLayoutJustifyContent)justifyContent alignItems:(ASStackLayoutAlignItems)alignItems flexWrap:(ASStackLayoutFlexWrap)flexWrap alignContent:(ASStackLayoutAlignContent)alignContent children:(NSArray *)children
{
  if (!(self = [super init])) {
    return nil;
  }
  _direction = direction;
  _spacing = spacing;
  _horizontalAlignment = ASHorizontalAlignmentNone;
  _verticalAlignment = ASVerticalAlignmentNone;
  _alignItems = alignItems;
  _justifyContent = justifyContent;
  _flexWrap = flexWrap;
  _alignContent = alignContent;
  
  [self setChildren:children];
  return self;
}

- (void)setDirection:(ASStackLayoutDirection)direction
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_direction != direction) {
    _direction = direction;
    [self resolveHorizontalAlignment];
    [self resolveVerticalAlignment];
  }
}

- (void)setHorizontalAlignment:(ASHorizontalAlignment)horizontalAlignment
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_horizontalAlignment != horizontalAlignment) {
    _horizontalAlignment = horizontalAlignment;
    [self resolveHorizontalAlignment];
  }
}

- (void)setVerticalAlignment:(ASVerticalAlignment)verticalAlignment
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  if (_verticalAlignment != verticalAlignment) {
    _verticalAlignment = verticalAlignment;
    [self resolveVerticalAlignment];
  }
}

- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _alignItems = alignItems;
}

- (void)setJustifyContent:(ASStackLayoutJustifyContent)justifyContent
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  ASDisplayNodeAssert(_horizontalAlignment == ASHorizontalAlignmentNone, @"Cannot set this property directly because horizontalAlignment is being used");
  ASDisplayNodeAssert(_verticalAlignment == ASVerticalAlignmentNone, @"Cannot set this property directly because verticalAlignment is being used");
  _justifyContent = justifyContent;
}

- (void)setSpacing:(CGFloat)spacing
{
  ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
  _spacing = spacing;
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  NSArray *children = self.children;
  if (children.count == 0) {
    return [ASLayout layoutWithLayoutElement:self size:constrainedSize.min];
  }
 
  // Accessing the style and size property is pretty costly we create layout spec children we use to figure
  // out the layout for each child
  const auto stackChildren = AS::map(children, [&](const id<ASLayoutElement> child) -> ASStackLayoutSpecChild {
    ASLayoutElementStyle *style = child.style;
    return {child, style, style.size};
  });
  
  const ASStackLayoutSpecStyle style = {.direction = _direction, .spacing = _spacing, .justifyContent = _justifyContent, .alignItems = _alignItems, .flexWrap = _flexWrap, .alignContent = _alignContent};
  
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(stackChildren, style, constrainedSize, _concurrent);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, style, constrainedSize);
  
  if (style.direction == ASStackLayoutDirectionVertical) {
    self.style.ascender = stackChildren.front().style.ascender;
    self.style.descender = stackChildren.back().style.descender;
  }
  
  NSMutableArray *sublayouts = [NSMutableArray array];
  for (const auto &item : positionedLayout.items) {
    [sublayouts addObject:item.layout];
  }

  return [ASLayout layoutWithLayoutElement:self size:positionedLayout.size sublayouts:sublayouts];
}

- (void)resolveHorizontalAlignment
{
  if (_direction == ASStackLayoutDirectionHorizontal) {
    _justifyContent = justifyContent(_horizontalAlignment, _justifyContent);
  } else {
    _alignItems = alignment(_horizontalAlignment, _alignItems);
  }
}

- (void)resolveVerticalAlignment
{
  if (_direction == ASStackLayoutDirectionHorizontal) {
    _alignItems = alignment(_verticalAlignment, _alignItems);
  } else {
    _justifyContent = justifyContent(_verticalAlignment, _justifyContent);
  }
}

@end

@implementation ASStackLayoutSpec (Debugging)

#pragma mark - ASLayoutElementAsciiArtProtocol

- (NSString *)asciiArtString
{
  return [ASLayoutSpec asciiArtStringForChildren:self.children parentName:[self asciiArtName] direction:self.direction];
}

@end
