/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASStackLayoutNode.h"

#import <numeric>
#import <vector>

#import "ASBaseDefines.h"
#import "ASInternalHelpers.h"

#import "ASLayoutNodeUtilities.h"
#import "ASStackLayoutNodeUtilities.h"
#import "ASStackPositionedLayout.h"
#import "ASStackUnpositionedLayout.h"

@implementation ASMutableStackLayoutNodeChild
@synthesize node, spacingBefore, spacingAfter, flexGrow, flexShrink, flexBasis, alignSelf;
@end

@implementation ASStackLayoutNodeChild

- (instancetype)initWithNode:(ASLayoutNode *)node
               spacingBefore:(CGFloat)spacingBefore
                spacingAfter:(CGFloat)spacingAfter
                    flexGrow:(BOOL)flexGrow
                  flexShrink:(BOOL)flexShrink
                   flexBasis:(ASRelativeDimension)flexBasis
                   alignSelf:(ASStackLayoutAlignSelf)alignSelf
{
  if (node == nil)
    return nil;
  
  if (self = [super init]) {
    _node = node;
    _spacingBefore = spacingBefore;
    _spacingAfter = spacingAfter;
    _flexGrow = flexGrow;
    _flexShrink = flexShrink;
    _flexBasis = flexBasis;
    _alignSelf = alignSelf;
  }
  return self;
}

- (id)copyWithZone:(NSZone *)zone
{
  if ([self isKindOfClass:[ASMutableStackLayoutNodeChild class]]) {
    return [[ASStackLayoutNodeChild alloc] initWithNode:self.node
                                          spacingBefore:self.spacingBefore
                                           spacingAfter:self.spacingAfter
                                               flexGrow:self.flexGrow
                                             flexShrink:self.flexShrink
                                              flexBasis:self.flexBasis
                                              alignSelf:self.alignSelf];
  } else {
    return self;
  }
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
  ASMutableStackLayoutNodeChild *mutableChild = [[ASMutableStackLayoutNodeChild alloc] init];
  mutableChild.node = self.node;
  mutableChild.spacingBefore = self.spacingBefore;
  mutableChild.spacingAfter = self.spacingAfter;
  mutableChild.flexGrow = self.flexGrow;
  mutableChild.flexShrink = self.flexShrink;
  mutableChild.flexBasis = self.flexBasis;
  mutableChild.alignSelf = self.alignSelf;
  return mutableChild;
}

+ (instancetype)newWithInitializer:(void (^)(ASMutableStackLayoutNodeChild *))initializer
{
  ASStackLayoutNodeChild *c = [super new];
  if (c && initializer) {
    ASMutableStackLayoutNodeChild *mutableChild = [[ASMutableStackLayoutNodeChild alloc] init];
    mutableChild.flexBasis = ASRelativeDimensionUnconstrained;
    initializer(mutableChild);
    c = [mutableChild copy];
  }
  return c;
}

@end


@implementation ASStackLayoutNode
{
  ASStackLayoutNodeStyle _style;
  std::vector<ASStackLayoutNodeChild *> _children;
}

+ (instancetype)newWithStyle:(ASStackLayoutNodeStyle)style children:(NSArray *)children
{
  ASStackLayoutNode *n = [super new];
  if (n) {
    n->_style = style;
    n->_children = std::vector<ASStackLayoutNodeChild *>();
    for (ASStackLayoutNodeChild *child in children) {
      if (child.node != nil) {
        n->_children.push_back(child);
      }
    }
  }
  return n;
}

+ (instancetype)new
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_children, _style, constrainedSize);
  const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, _style, constrainedSize);
  const CGSize finalSize = directionSize(_style.direction, unpositionedLayout.stackDimensionSum, positionedLayout.crossSize);
  NSArray *children = [NSArray arrayWithObjects:&positionedLayout.children[0] count:positionedLayout.children.size()];
  return [ASLayout newWithLayoutableObject:self
                                      size:ASSizeRangeClamp(constrainedSize, finalSize)
                                  children:children];
}

@end
