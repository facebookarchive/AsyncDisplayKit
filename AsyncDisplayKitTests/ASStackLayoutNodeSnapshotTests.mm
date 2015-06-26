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

#import "ASStackLayoutNode.h"
#import "ASBackgroundLayoutNode.h"
#import "ASRatioLayoutNode.h"
#import "ASInsetLayoutNode.h"

@interface ASStackLayoutNodeSnapshotTests : ASLayoutNodeSnapshotTestCase
@end

@implementation ASStackLayoutNodeSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

static NSArray *defaultSubnodes()
{
  return defaultSubnodesWithSameSize(CGSizeZero, NO);
}

static NSArray *defaultSubnodesWithSameSize(CGSize subnodeSize, BOOL flex)
{
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor redColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor greenColor])
                        ];
  for (ASStaticSizeDisplayNode *subnode in subnodes) {
    subnode.staticSize = subnodeSize;
    subnode.flexGrow = flex;
    subnode.flexShrink = flex;
  }
  return subnodes;
}

- (void)testStackLayoutNodeWithJustify:(ASStackLayoutJustifyContent)justify
                                  flex:(BOOL)flex
                             sizeRange:(ASSizeRange)sizeRange
                            identifier:(NSString *)identifier
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionHorizontal,
    .justifyContent = justify
  };
  
  NSArray *subnodes = defaultSubnodesWithSameSize({50, 50}, flex);
  
  [self testStackLayoutNodeWithStyle:style sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutNodeWithStyle:(ASStackLayoutNodeStyle)style
                           sizeRange:(ASSizeRange)sizeRange
                            subnodes:(NSArray *)subnodes
                          identifier:(NSString *)identifier
{
  [self testStackLayoutNodeWithStyle:style children:subnodes sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutNodeWithStyle:(ASStackLayoutNodeStyle)style
                            children:(NSArray *)children
                           sizeRange:(ASSizeRange)sizeRange
                            subnodes:(NSArray *)subnodes
                          identifier:(NSString *)identifier
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor whiteColor]);
  
  ASLayoutNode *layoutNode =
  [ASBackgroundLayoutNode
   newWithChild:[ASStackLayoutNode newWithStyle:style children:children]
   background:backgroundNode];
  
  NSMutableArray *newSubnodes = [NSMutableArray arrayWithObject:backgroundNode];
  [newSubnodes addObjectsFromArray:subnodes];
  
  [self testLayoutNode:layoutNode sizeRange:sizeRange subnodes:newSubnodes identifier:identifier];
}

- (void)testUnderflowBehaviors
{
  // width 300px; height 0-300px
  static ASSizeRange kSize = {{300, 0}, {300, 300}};
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentStart flex:NO sizeRange:kSize identifier:@"justifyStart"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentCenter flex:NO sizeRange:kSize identifier:@"justifyCenter"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentEnd flex:NO sizeRange:kSize identifier:@"justifyEnd"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentStart flex:YES sizeRange:kSize identifier:@"flex"];
}

- (void)testOverflowBehaviors
{
  // width 110px; height 0-300px
  static ASSizeRange kSize = {{110, 0}, {110, 300}};
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentStart flex:NO sizeRange:kSize identifier:@"justifyStart"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentCenter flex:NO sizeRange:kSize identifier:@"justifyCenter"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentEnd flex:NO sizeRange:kSize identifier:@"justifyEnd"];
  [self testStackLayoutNodeWithJustify:ASStackLayoutJustifyContentStart flex:YES sizeRange:kSize identifier:@"flex"];
}

- (void)testOverflowBehaviorsWhenAllFlexShrinkNodesHaveBeenClampedToZeroButViolationStillExists
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodesWithSameSize({50, 50}, NO);
  ((ASDisplayNode *)subnodes[1]).flexShrink = YES;
  
  // Width is 75px--that's less than the sum of the widths of the child nodes, which is 100px.
  static ASSizeRange kSize = {{75, 0}, {75, 150}};
  [self testStackLayoutNodeWithStyle: style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFlexWithUnequalIntrinsicSizes
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodesWithSameSize({50, 50}, YES);
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {150, 150};

  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];
  
  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testCrossAxisSizeBehaviors
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionVertical};

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 50};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 50};
  
  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
  
  // width 300px; height 300px
  static ASSizeRange kFixedHeight = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kFixedHeight subnodes:subnodes identifier:@"fixedHeight"];
}

- (void)testStackSpacing
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .spacing = 10
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 50};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 50};

  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testStackSpacingWithChildrenHavingNilNodes
{
  // This should take a zero height since all children have a nil node. If it takes a height > 0, a blue background
  // will show up, hence failing the test.
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);

  ASLayoutNode *layoutNode =
  [ASInsetLayoutNode
   newWithInsets:{10, 10, 10 ,10}
   child:
   [ASBackgroundLayoutNode
    newWithChild:
    [ASStackLayoutNode
     newWithStyle:{
       .direction = ASStackLayoutDirectionVertical,
       .spacing = 10,
       .alignItems = ASStackLayoutAlignItemsStretch
     }
     children:@[]]
    background:backgroundNode]];
  
  // width 300px; height 0-300px
  static ASSizeRange kVariableHeight = {{300, 0}, {300, 300}};
  [self testLayoutNode:layoutNode sizeRange:kVariableHeight subnodes:@[backgroundNode] identifier:@"variableHeight"];
}

- (void)testNodeSpacing
{
  // width 0-INF; height 0-INF
  static ASSizeRange kAnySize = {{0, 0}, {INFINITY, INFINITY}};
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionVertical};

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};
  
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 10;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 20;
  [self testStackLayoutNodeWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBefore"];
  // Reset above spacing values
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 0;

  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingAfter = 10;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingAfter = 20;
  [self testStackLayoutNodeWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingAfter"];
  // Reset above spacing values
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingAfter = 0;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingAfter = 0;
  
  style.spacing = 10;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = -10;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingAfter = -10;
  [self testStackLayoutNodeWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBalancedOut"];
}

- (void)testJustifiedCenterWithNodeSpacing
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};

  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testNodeThatChangesCrossSizeWhenMainSizeIsFlexed
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  ASStaticSizeDisplayNode * subnode1 = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASStaticSizeDisplayNode * subnode2 = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  subnode2.staticSize = {50, 50};
  
  ASRatioLayoutNode *child1 = [ASRatioLayoutNode newWithRatio:1.5 child:subnode1];
  child1.flexBasis = ASRelativeDimensionMakeWithPercent(1);
  child1.flexGrow = YES;
  child1.flexShrink = YES;
  
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutNodeWithStyle:style children:@[child1, subnode2] sizeRange:kFixedWidth subnodes:@[subnode1, subnode2] identifier:nil];
}

- (void)testAlignCenterWithFlexedMainDimension
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .alignItems = ASStackLayoutAlignItemsCenter
  };

  ASStaticSizeDisplayNode *subnode1 = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  subnode1.staticSize = {100, 100};
  subnode1.flexShrink = YES;

  ASStaticSizeDisplayNode *subnode2 = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  subnode2.staticSize = {50, 50};
  subnode2.flexShrink = YES;

  NSArray *subnodes = @[subnode1, subnode2];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, 100}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignCenterWithIndefiniteCrossDimension
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  ASStaticSizeDisplayNode *subnode1 = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  subnode1.staticSize = {100, 100};
  
  ASStaticSizeDisplayNode *subnode2 = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  subnode2.staticSize = {50, 50};
  subnode2.alignSelf = ASStackLayoutAlignSelfCenter;

  NSArray *subnodes = @[subnode1, subnode2];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignedStart
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStart
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};
  
  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedEnd
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsEnd
  };
  
  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};
  
  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedCenter
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsCenter
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};
  
  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchNoChildExceedsMin
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};

  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  static ASSizeRange kVariableSize = {{200, 200}, {300, 300}};
  // all children should be 200px wide
  [self testStackLayoutNodeWithStyle:style sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchOneChildExceedsMin
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 70};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {150, 90};
  
  ((ASStaticSizeDisplayNode *)subnodes[0]).spacingBefore = 0;
  ((ASStaticSizeDisplayNode *)subnodes[1]).spacingBefore = 20;
  ((ASStaticSizeDisplayNode *)subnodes[2]).spacingBefore = 30;

  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  // all children should be 150px wide
  [self testStackLayoutNodeWithStyle:style sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testEmptyStack
{
  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  [self testStackLayoutNodeWithStyle:{} sizeRange:kVariableSize subnodes:@[] identifier:nil];
}

- (void)testFixedFlexBasisAppliedWhenFlexingItems
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodesWithSameSize({50, 50}, NO);
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {150, 150};

  for (ASStaticSizeDisplayNode *subnode in subnodes) {
    subnode.flexGrow = YES;
    subnode.flexBasis = ASRelativeDimensionMakeWithPoints(10);
  }

  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];

  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testPercentageFlexBasisResolvesAgainstParentSize
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodesWithSameSize({50, 50}, NO);
  
  for (ASStaticSizeDisplayNode *subnode in subnodes) {
    subnode.flexGrow = YES;
  }

  // This should override the intrinsic size of 50pts and instead compute to 50% = 100pts.
  // The result should be that the red box is twice as wide as the blue and gree boxes after flexing.
  ((ASStaticSizeDisplayNode *)subnodes[0]).flexBasis = ASRelativeDimensionMakeWithPercent(0.5);

  static ASSizeRange kSize = {{200, 0}, {200, INFINITY}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFixedFlexBasisOverridesIntrinsicSizeForNonFlexingChildren
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodes();
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {50, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {150, 150};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {50, 50};

  for (ASStaticSizeDisplayNode *subnode in subnodes) {
    subnode.flexBasis = ASRelativeDimensionMakeWithPoints(20);
  }
  
  static ASSizeRange kSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testCrossAxisStretchingOccursAfterStackAxisFlexing
{
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor greenColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor redColor])
                        ];
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {10, 0};
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {3000, 3000};
  
  ASRatioLayoutNode *child2 = [ASRatioLayoutNode newWithRatio:1.0 child:subnodes[2]];
  child2.flexGrow = YES;
  child2.flexShrink = YES;

  // If cross axis stretching occurred *before* flexing, then the blue child would be stretched to 3000 points tall.
  // Instead it should be stretched to 300 points tall, matching the red child and not overlapping the green inset.
  ASLayoutNode *layoutNode =
  [ASBackgroundLayoutNode
   newWithChild:
   [ASInsetLayoutNode
    newWithInsets:UIEdgeInsetsMake(10, 10, 10, 10)
    child:
    [ASStackLayoutNode
     newWithStyle:{
      .direction = ASStackLayoutDirectionHorizontal,
      .alignItems = ASStackLayoutAlignItemsStretch,
     }
     children:@[subnodes[1], child2,]]]
   background:subnodes[0]];

  static ASSizeRange kSize = {{300, 0}, {300, INFINITY}};
  [self testLayoutNode:layoutNode sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testViolationIsDistributedEquallyAmongFlexibleChildNodes
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray *subnodes = defaultSubnodes();
  
  ((ASStaticSizeDisplayNode *)subnodes[0]).staticSize = {300, 50};
  ((ASStaticSizeDisplayNode *)subnodes[0]).flexShrink = YES;
  
  ((ASStaticSizeDisplayNode *)subnodes[1]).staticSize = {100, 50};
  ((ASStaticSizeDisplayNode *)subnodes[1]).flexShrink = NO;
  
  ((ASStaticSizeDisplayNode *)subnodes[2]).staticSize = {200, 50};
  ((ASStaticSizeDisplayNode *)subnodes[2]).flexShrink = YES;
  
  // A width of 400px results in a violation of 200px. This is distributed equally among each flexible node,
  // causing both of them to be shrunk by 100px, resulting in widths of 300px, 100px, and 50px.
  // In the W3 flexbox standard, flexible nodes are shrunk proportionate to their original sizes,
  // resulting in widths of 180px, 100px, and 120px.
  // This test verifies the current behavior--the snapshot contains widths 300px, 100px, and 50px.
  static ASSizeRange kSize = {{400, 0}, {400, 150}};
  [self testStackLayoutNodeWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

@end
