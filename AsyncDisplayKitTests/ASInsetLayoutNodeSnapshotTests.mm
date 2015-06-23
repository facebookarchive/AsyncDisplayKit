/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutNodeSnapshotTestsHelper.h"

#import "ASBackgroundLayoutNode.h"
#import "ASInsetLayoutNode.h"
#import "ASStaticLayoutNode.h"


typedef NS_OPTIONS(NSUInteger, ASInsetLayoutNodeTestEdge) {
  ASInsetLayoutNodeTestEdgeTop    = 1 << 0,
  ASInsetLayoutNodeTestEdgeLeft   = 1 << 1,
  ASInsetLayoutNodeTestEdgeBottom = 1 << 2,
  ASInsetLayoutNodeTestEdgeRight  = 1 << 3,
};

static CGFloat insetForEdge(NSUInteger combination, ASInsetLayoutNodeTestEdge edge, CGFloat insetValue)
{
  return combination & edge ? INFINITY : insetValue;
}

static UIEdgeInsets insetsForCombination(NSUInteger combination, CGFloat insetValue)
{
  return {
    .top = insetForEdge(combination, ASInsetLayoutNodeTestEdgeTop, insetValue),
    .left = insetForEdge(combination, ASInsetLayoutNodeTestEdgeLeft, insetValue),
    .bottom = insetForEdge(combination, ASInsetLayoutNodeTestEdgeBottom, insetValue),
    .right = insetForEdge(combination, ASInsetLayoutNodeTestEdgeRight, insetValue),
  };
}

static NSString *nameForInsets(UIEdgeInsets insets)
{
  return [NSString stringWithFormat:@"%.f-%.f-%.f-%.f", insets.top, insets.left, insets.bottom, insets.right];
}

@interface ASInsetLayoutNodeSnapshotTests : ASLayoutNodeSnapshotTestCase
@end

@implementation ASInsetLayoutNodeSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testInsetsWithVariableSize
{
  for (NSUInteger combination = 0; combination < 16; combination++) {
    UIEdgeInsets insets = insetsForCombination(combination, 10);
    ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor grayColor]);
    ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
    foregroundNode.staticSize = {10, 10};
    
    ASLayoutNode *layoutNode =
    [ASBackgroundLayoutNode
     newWithNode:
     [ASInsetLayoutNode
      newWithInsets:insets
      node:[ASCompositeNode newWithDisplayNode:foregroundNode]]
     background:[ASCompositeNode newWithDisplayNode:backgroundNode]];
    
    static ASSizeRange kVariableSize = {{0, 0}, {300, 300}};
    [self testLayoutNode:layoutNode
               sizeRange:kVariableSize
                subnodes:@[backgroundNode, foregroundNode]
              identifier:nameForInsets(insets)];
  }
}

- (void)testInsetsWithFixedSize
{
  for (NSUInteger combination = 0; combination < 16; combination++) {
    UIEdgeInsets insets = insetsForCombination(combination, 10);
    ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor grayColor]);
    ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
    foregroundNode.staticSize = {10, 10};
    
    ASLayoutNode *layoutNode =
    [ASBackgroundLayoutNode
     newWithNode:
     [ASInsetLayoutNode
      newWithInsets:insets
      node:[ASCompositeNode newWithDisplayNode:foregroundNode]]
     background:[ASCompositeNode newWithDisplayNode:backgroundNode]];

    static ASSizeRange kFixedSize = {{300, 300}, {300, 300}};
    [self testLayoutNode:layoutNode
               sizeRange:kFixedSize
                subnodes:@[backgroundNode, foregroundNode]
              identifier:nameForInsets(insets)];
  }
}

/** Regression test, there was a bug mixing insets with infinite and zero sizes */
- (void)testInsetsWithInfinityAndZeroInsetValue
{
  for (NSUInteger combination = 0; combination < 16; combination++) {
    UIEdgeInsets insets = insetsForCombination(combination, 0);
    ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor grayColor]);
    ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
    foregroundNode.staticSize = {10, 10};

    ASLayoutNode *layoutNode =
    [ASBackgroundLayoutNode
     newWithNode:
     [ASInsetLayoutNode
      newWithInsets:insets
      node:[ASCompositeNode newWithDisplayNode:foregroundNode]]
     background:[ASCompositeNode newWithDisplayNode:backgroundNode]];

    static ASSizeRange kFixedSize = {{300, 300}, {300, 300}};
    [self testLayoutNode:layoutNode
               sizeRange:kFixedSize
                subnodes:@[backgroundNode, foregroundNode]
              identifier:nameForInsets(insets)];
  }
}

@end
