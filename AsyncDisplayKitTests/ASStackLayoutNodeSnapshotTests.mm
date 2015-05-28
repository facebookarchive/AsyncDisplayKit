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

static ASStackLayoutNodeChild *flexChild(ASLayoutNode *n, BOOL flex)
{
  return [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
    mutableChild.node = n;
    mutableChild.flexGrow = flex;
    mutableChild.flexShrink = flex;
  }];
}

static NSArray *defaultSubnodes()
{
  return @[
           ASDisplayNodeWithBackgroundColor([UIColor redColor]),
           ASDisplayNodeWithBackgroundColor([UIColor blueColor]),
           ASDisplayNodeWithBackgroundColor([UIColor greenColor])
           ];
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
  ASLayoutNodeSize subnodeSize = ASLayoutNodeSizeMake(50, 50);
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        flexChild([ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[0]], flex),
                        flexChild([ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[1]], flex),
                        flexChild([ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[2]], flex)
                        ];
  
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:sizeRange subnodes:subnodes identifier:identifier];
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
   newWithNode:[ASStackLayoutNode newWithSize:{} style:style children:children]
   background:[ASCompositeNode newWithDisplayNode:backgroundNode]];
  
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
  ASLayoutNodeSize subnodeSize = ASLayoutNodeSizeMake(50, 50);
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        // After flexShrink-able children are all clamped to zero, the sum of their widths is 100px.
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[0]];
                          mutableChild.flexShrink = NO;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[1]];
                          mutableChild.flexShrink = YES;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:subnodeSize displayNode:subnodes[2]];
                          mutableChild.flexShrink = NO;
                        }]
                        ];
  // Width is 75px--that's less than the sum of the widths of the child nodes, which is 100px.
  static ASSizeRange kSize = {{75, 0}, {75, 150}};
  [self testStackLayoutNodeWithStyle: style children:children sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFlexWithUnequalIntrinsicSizes
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        flexChild([ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]], YES),
                        flexChild([ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 150) displayNode:subnodes[1]], YES),
                        flexChild([ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[2]], YES)
                        ];

  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];
  
  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testCrossAxisSizeBehaviors
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionVertical};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 50) displayNode:subnodes[1]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 50) displayNode:subnodes[2]];
                        }]
                        ];
  
  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
  
  // width 300px; height 300px
  static ASSizeRange kFixedHeight = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kFixedHeight subnodes:subnodes identifier:@"fixedHeight"];
}

- (void)testStackSpacing
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .spacing = 10
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 50) displayNode:subnodes[1]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 50) displayNode:subnodes[2]];
                        }]
                        ];
  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testStackSpacingWithChildrenHavingNilNodes
{
  // This should take a zero height since all children have a nil node. If it takes a height > 0, a blue background
  // will show up, hence failing the test.
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);

  ASLayoutNode *layoutNode =
  [ASInsetLayoutNode
   newWithInsets:{10, 10, 10 ,10}
   node:
   [ASBackgroundLayoutNode
    newWithNode:
    [ASStackLayoutNode
     newWithSize:{}
     style:{
       .direction = ASStackLayoutDirectionVertical,
       .spacing = 10,
       .alignItems = ASStackLayoutAlignItemsStretch
     }
     children:@[
                [ASStackLayoutNodeChild new],
                [ASStackLayoutNodeChild new]
                ]]
    background:[ASCompositeNode newWithDisplayNode:backgroundNode]]];
  
  // width 300px; height 0-300px
  static ASSizeRange kVariableHeight = {{300, 0}, {300, 300}};
  [self testLayoutNode:layoutNode sizeRange:kVariableHeight subnodes:@[backgroundNode] identifier:@"variableHeight"];
}

- (void)testNodeSpacing
{
  // width 0-INF; height 0-INF
  static ASSizeRange kAnySize = {{0, 0}, {INFINITY, INFINITY}};
  NSArray *subnodes = defaultSubnodes();
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionVertical};
  
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 10;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 20;
                        }]
                        ];
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBefore"];

  children = @[
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
               }],
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                 mutableChild.spacingAfter = 10;
               }],
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                 mutableChild.spacingAfter = 20;
               }]
               ];
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kAnySize subnodes:subnodes identifier:@"spacingAfter"];

  style.spacing = 10;
  children = @[
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
               }],
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                 mutableChild.spacingBefore = -10;
                 mutableChild.spacingAfter = -10;
               }],
               [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                 mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
               }]
               ];
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBalancedOut"];
}

- (void)testJustifiedCenterWithNodeSpacing
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];

  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testNodeThatChangesCrossSizeWhenMainSizeIsFlexed
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor redColor])
                        ];
  NSArray *children = @[
                      [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                        mutableChild.node = [ASRatioLayoutNode
                                             newWithRatio:1.5
                                             size:{}
                                             node:[ASCompositeNode newWithSize:ASLayoutNodeSizeMake(00, 150) displayNode:subnodes[0]]];;
                        mutableChild.flexBasis = ASRelativeDimensionMakeWithPercent(1);
                        mutableChild.flexGrow = YES;
                        mutableChild.flexShrink = YES;
                      }],
                      [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                        mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[1]];
                      }]
                      ];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignCenterWithFlexedMainDimension
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .alignItems = ASStackLayoutAlignItemsCenter
  };
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor redColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor])
                        ];
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 100) displayNode:subnodes[0]];
                          mutableChild.flexShrink = YES;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[1]];
                          mutableChild.flexShrink = YES;
                        }],
                        ];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, 100}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignCenterWithIndefiniteCrossDimension
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor redColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor])
                        ];
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 100) displayNode:subnodes[0]];
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[1]];
                          mutableChild.alignSelf = ASStackLayoutAlignSelfCenter;
                        }],
                        ];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignedStart
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStart
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];
  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedEnd
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsEnd
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];
  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedCenter
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsCenter
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];
  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchNoChildExceedsMin
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];
  static ASSizeRange kVariableSize = {{200, 200}, {300, 300}};
  // all children should be 200px wide
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchOneChildExceedsMin
{
  ASStackLayoutNodeStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.spacingBefore = 0;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 70) displayNode:subnodes[1]];
                          mutableChild.spacingBefore = 20;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 90) displayNode:subnodes[2]];
                          mutableChild.spacingBefore = 30;
                        }]
                        ];
  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  // all children should be 150px wide
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testEmptyStack
{
  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  [self testStackLayoutNodeWithStyle:{} children:@[] sizeRange:kVariableSize subnodes:@[] identifier:nil];
}

- (void)testFixedFlexBasisAppliedWhenFlexingItems
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.flexGrow = YES;
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(10);
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 150) displayNode:subnodes[1]];
                          mutableChild.flexGrow = YES;
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(10);
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[2]];
                          mutableChild.flexGrow = YES;
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(10);
                        }]
                        ];
  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];

  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testPercentageFlexBasisResolvesAgainstParentSize
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.flexGrow = YES;
                          // This should override the intrinsic size of 50pts and instead compute to 50% = 100pts.
                          // The result should be that the red box is twice as wide as the blue and gree boxes after flexing.
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPercent(0.5);
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[1]];
                          mutableChild.flexGrow = YES;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[2]];
                          mutableChild.flexGrow = YES;
                        }]
                        ];
  static ASSizeRange kSize = {{200, 0}, {200, INFINITY}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFixedFlexBasisOverridesIntrinsicSizeForNonFlexingChildren
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[0]];
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(20);
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(150, 150) displayNode:subnodes[1]];
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(20);
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(50, 50) displayNode:subnodes[2]];
                          mutableChild.flexBasis = ASRelativeDimensionMakeWithPoints(20);
                        }]
                        ];
  static ASSizeRange kSize = {{300, 0}, {300, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testCrossAxisStretchingOccursAfterStackAxisFlexing
{
  NSArray *subnodes = @[
                        ASDisplayNodeWithBackgroundColor([UIColor greenColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor blueColor]),
                        ASDisplayNodeWithBackgroundColor([UIColor redColor])
                        ];

  // If cross axis stretching occurred *before* flexing, then the blue child would be stretched to 3000 points tall.
  // Instead it should be stretched to 300 points tall, matching the red child and not overlapping the green inset.
  ASLayoutNode *layoutNode =
  [ASBackgroundLayoutNode
   newWithNode:
   [ASInsetLayoutNode
    newWithInsets:UIEdgeInsetsMake(10, 10, 10, 10)
    node:
   [ASStackLayoutNode
    newWithSize:{}
    style:{
      .direction = ASStackLayoutDirectionHorizontal,
      .alignItems = ASStackLayoutAlignItemsStretch,
    }
    children:
    @[
      [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
        mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(10, 00) displayNode:subnodes[1]];
      }],
      flexChild([ASRatioLayoutNode
                 newWithRatio:1.0
                 size:{}
                 node:[ASCompositeNode newWithSize:ASLayoutNodeSizeMake(3000, 3000) displayNode:subnodes[2]]],
                YES),
    ]]]
   background:[ASCompositeNode newWithDisplayNode:subnodes[0]]];

  static ASSizeRange kSize = {{300, 0}, {300, INFINITY}};
  [self testLayoutNode:layoutNode sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testViolationIsDistributedEquallyAmongFlexibleChildNodes
{
  ASStackLayoutNodeStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  NSArray *subnodes = defaultSubnodes();
  NSArray *children = @[
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(300, 50) displayNode:subnodes[0]];
                          mutableChild.flexShrink = YES;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(100, 50) displayNode:subnodes[1]];
                          mutableChild.flexShrink = NO;
                        }],
                        [ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
                          mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(200, 50) displayNode:subnodes[2]];
                          mutableChild.flexShrink = YES;
                        }]
                        ];
  // A width of 400px results in a violation of 200px. This is distributed equally among each flexible node,
  // causing both of them to be shrunk by 100px, resulting in widths of 300px, 100px, and 50px.
  // In the W3 flexbox standard, flexible nodes are shrunk proportionate to their original sizes,
  // resulting in widths of 180px, 100px, and 120px.
  // This test verifies the current behavior--the snapshot contains widths 300px, 100px, and 50px.
  static ASSizeRange kSize = {{400, 0}, {400, 150}};
  [self testStackLayoutNodeWithStyle:style children:children sizeRange:kSize subnodes:subnodes identifier:nil];
}

@end
