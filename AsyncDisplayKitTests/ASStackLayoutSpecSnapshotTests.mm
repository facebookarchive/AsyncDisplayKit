//
//  ASStackLayoutSpecSnapshotTests.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import "ASStackLayoutSpec.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASBackgroundLayoutSpec.h"
#import "ASRatioLayoutSpec.h"
#import "ASInsetLayoutSpec.h"

@interface ASStackLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASStackLayoutSpecSnapshotTests

#pragma mark - Utility methods

static NSArray<ASDisplayNode *> *defaultSubnodes()
{
  return defaultSubnodesWithSameSize(CGSizeZero, 0);
}

static NSArray<ASDisplayNode *> *defaultSubnodesWithSameSize(CGSize subnodeSize, CGFloat flex)
{
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor redColor], subnodeSize),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], subnodeSize),
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], subnodeSize)
  ];
  for (ASDisplayNode *subnode in subnodes) {
    subnode.style.flexGrow = flex;
    subnode.style.flexShrink = flex;
  }
  return subnodes;
}

static void setCGSizeToNode(CGSize size, ASDisplayNode *node)
{
  node.style.width = ASDimensionMakeWithPoints(size.width);
  node.style.height = ASDimensionMakeWithPoints(size.height);
}

- (void)testDefaultStackLayoutElementFlexProperties
{
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  
  XCTAssertEqual(displayNode.style.flexShrink, NO);
  XCTAssertEqual(displayNode.style.flexGrow, NO);
  
  const ASDimension unconstrainedDimension = ASDimensionAuto;
  const ASDimension flexBasis = displayNode.style.flexBasis;
  XCTAssertEqual(flexBasis.unit, unconstrainedDimension.unit);
  XCTAssertEqual(flexBasis.value, unconstrainedDimension.value);
}

- (void)testStackLayoutSpecWithJustify:(ASStackLayoutJustifyContent)justify
                            flexFactor:(CGFloat)flex
                             sizeRange:(ASSizeRange)sizeRange
                            identifier:(NSString *)identifier
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionHorizontal,
    .justifyContent = justify
  };
  
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, flex);
  
  [self testStackLayoutSpecWithStyle:style sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutSpecWithDirection:(ASStackLayoutDirection)direction
                itemsHorizontalAlignment:(ASHorizontalAlignment)horizontalAlignment
                  itemsVerticalAlignment:(ASVerticalAlignment)verticalAlignment
                              identifier:(NSString *)identifier
{
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  
  ASStackLayoutSpec *stackLayoutSpec = [[ASStackLayoutSpec alloc] init];
  stackLayoutSpec.direction = direction;
  stackLayoutSpec.children = subnodes;
  stackLayoutSpec.horizontalAlignment = horizontalAlignment;
  stackLayoutSpec.verticalAlignment = verticalAlignment;
  
  CGSize exactSize = CGSizeMake(200, 200);
  static ASSizeRange kSize = ASSizeRangeMake(exactSize, exactSize);
  [self testStackLayoutSpec:stackLayoutSpec sizeRange:kSize subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutSpecWithStyle:(ASStackLayoutSpecStyle)style
                           sizeRange:(ASSizeRange)sizeRange
                            subnodes:(NSArray *)subnodes
                          identifier:(NSString *)identifier
{
  [self testStackLayoutSpecWithStyle:style children:subnodes sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutSpecWithStyle:(ASStackLayoutSpecStyle)style
                            children:(NSArray *)children
                           sizeRange:(ASSizeRange)sizeRange
                            subnodes:(NSArray *)subnodes
                          identifier:(NSString *)identifier
{
  ASStackLayoutSpec *stackLayoutSpec =
  [ASStackLayoutSpec
   stackLayoutSpecWithDirection:style.direction
   spacing:style.spacing
   justifyContent:style.justifyContent
   alignItems:style.alignItems
   children:children];

  [self testStackLayoutSpec:stackLayoutSpec sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

- (void)testStackLayoutSpec:(ASStackLayoutSpec *)stackLayoutSpec
                  sizeRange:(ASSizeRange)sizeRange
                   subnodes:(NSArray *)subnodes
                 identifier:(NSString *)identifier
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor whiteColor]);
  ASLayoutSpec *layoutSpec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:stackLayoutSpec background:backgroundNode];
  
  NSMutableArray *newSubnodes = [NSMutableArray arrayWithObject:backgroundNode];
  [newSubnodes addObjectsFromArray:subnodes];
  
  [self testLayoutSpec:layoutSpec sizeRange:sizeRange subnodes:newSubnodes identifier:identifier];
}

#pragma mark -

- (void)testUnderflowBehaviors
{
  // width 300px; height 0-300px
  static ASSizeRange kSize = {{300, 0}, {300, 300}};
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentStart flexFactor:0 sizeRange:kSize identifier:@"justifyStart"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentCenter flexFactor:0 sizeRange:kSize identifier:@"justifyCenter"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentEnd flexFactor:0 sizeRange:kSize identifier:@"justifyEnd"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentStart flexFactor:1 sizeRange:kSize identifier:@"flex"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceBetween flexFactor:0 sizeRange:kSize identifier:@"justifySpaceBetween"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceAround flexFactor:0 sizeRange:kSize identifier:@"justifySpaceAround"];
}

- (void)testOverflowBehaviors
{
  // width 110px; height 0-300px
  static ASSizeRange kSize = {{110, 0}, {110, 300}};
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentStart flexFactor:0 sizeRange:kSize identifier:@"justifyStart"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentCenter flexFactor:0 sizeRange:kSize identifier:@"justifyCenter"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentEnd flexFactor:0 sizeRange:kSize identifier:@"justifyEnd"];
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentStart flexFactor:1 sizeRange:kSize identifier:@"flex"];
  // On overflow, "space between" is identical to "content start"
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceBetween flexFactor:0 sizeRange:kSize identifier:@"justifyStart"];
  // On overflow, "space around" is identical to "content center"
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceAround flexFactor:0 sizeRange:kSize identifier:@"justifyCenter"];
}

- (void)testOverflowBehaviorsWhenAllFlexShrinkChildrenHaveBeenClampedToZeroButViolationStillExists
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  subnodes[1].style.flexShrink = 1;
  
  // Width is 75px--that's less than the sum of the widths of the children, which is 100px.
  static ASSizeRange kSize = {{75, 0}, {75, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFlexWithUnequalIntrinsicSizes
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 1);
  setCGSizeToNode({150, 150}, subnodes[1]);

  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];
  
  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testCrossAxisSizeBehaviors
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 50}, subnodes[1]);
  setCGSizeToNode({150, 50}, subnodes[2]);
  
  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
  
  // width 300px; height 300px
  static ASSizeRange kFixedHeight = {{300, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kFixedHeight subnodes:subnodes identifier:@"fixedHeight"];
}

- (void)testStackSpacing
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .spacing = 10
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 50}, subnodes[1]);
  setCGSizeToNode({150, 50}, subnodes[2]);

  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testStackSpacingWithChildrenHavingNilObjects
{
  // This should take a zero height since all children have a nil node. If it takes a height > 0, a blue background
  // will show up, hence failing the test.
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);

  ASLayoutSpec *layoutSpec =
  [ASInsetLayoutSpec
   insetLayoutSpecWithInsets:{10, 10, 10, 10}
   child:
   [ASBackgroundLayoutSpec
    backgroundLayoutSpecWithChild:
    [ASStackLayoutSpec
     stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
     spacing:10
     justifyContent:ASStackLayoutJustifyContentStart
     alignItems:ASStackLayoutAlignItemsStretch
     children:@[]]
    background:backgroundNode]];
  
  // width 300px; height 0-300px
  static ASSizeRange kVariableHeight = {{300, 0}, {300, 300}};
  [self testLayoutSpec:layoutSpec sizeRange:kVariableHeight subnodes:@[backgroundNode] identifier:@"variableHeight"];
}

- (void)testChildSpacing
{
  // width 0-INF; height 0-INF
  static ASSizeRange kAnySize = {{0, 0}, {INFINITY, INFINITY}};
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);
  
  subnodes[1].style.spacingBefore = 10;
  subnodes[2].style.spacingBefore = 20;
  [self testStackLayoutSpecWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBefore"];
  // Reset above spacing values
  subnodes[1].style.spacingBefore = 0;
  subnodes[2].style.spacingBefore = 0;

  subnodes[1].style.spacingAfter = 10;
  subnodes[2].style.spacingAfter = 20;
  [self testStackLayoutSpecWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingAfter"];
  // Reset above spacing values
  subnodes[1].style.spacingAfter = 0;
  subnodes[2].style.spacingAfter = 0;
  
  style.spacing = 10;
  subnodes[1].style.spacingBefore = -10;
  subnodes[1].style.spacingAfter = -10;
  [self testStackLayoutSpecWithStyle:style sizeRange:kAnySize subnodes:subnodes identifier:@"spacingBalancedOut"];
}

- (void)testJustifiedCenterWithChildSpacing
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);

  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  // width 0-300px; height 300px
  static ASSizeRange kVariableHeight = {{0, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableHeight subnodes:subnodes identifier:@"variableHeight"];
}

- (void)testJustifiedSpaceBetweenWithOneChild
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionHorizontal,
    .justifyContent = ASStackLayoutJustifyContentSpaceBetween
  };

  ASDisplayNode *child = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  
  // width 300px; height 0-INF
  static ASSizeRange kVariableHeight = {{300, 0}, {300, INFINITY}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableHeight subnodes:@[child] identifier:nil];
}

- (void)testJustifiedSpaceAroundWithOneChild
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionHorizontal,
    .justifyContent = ASStackLayoutJustifyContentSpaceAround
  };
  
  ASDisplayNode *child = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  
  // width 300px; height 0-INF
  static ASSizeRange kVariableHeight = {{300, 0}, {300, INFINITY}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableHeight subnodes:@[child] identifier:nil];
}

- (void)testJustifiedSpaceBetweenWithRemainingSpace
{
  // width 301px; height 0-300px; 1px remaining
  static ASSizeRange kSize = {{301, 0}, {301, 300}};
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceBetween flexFactor:0 sizeRange:kSize identifier:nil];
}

- (void)testJustifiedSpaceAroundWithRemainingSpace
{
  // width 305px; height 0-300px; 5px remaining
  static ASSizeRange kSize = {{305, 0}, {305, 300}};
  [self testStackLayoutSpecWithJustify:ASStackLayoutJustifyContentSpaceAround flexFactor:0 sizeRange:kSize identifier:nil];
}

- (void)testChildThatChangesCrossSizeWhenMainSizeIsFlexed
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  ASDisplayNode *subnode1 = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASDisplayNode *subnode2 = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  
  ASRatioLayoutSpec *child1 = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:1.5 child:subnode1];
  child1.style.flexBasis = ASDimensionMakeWithFraction(1);
  child1.style.flexGrow = 1;
  child1.style.flexShrink = 1;
  
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutSpecWithStyle:style children:@[child1, subnode2] sizeRange:kFixedWidth subnodes:@[subnode1, subnode2] identifier:nil];
}

- (void)testAlignCenterWithFlexedMainDimension
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .alignItems = ASStackLayoutAlignItemsCenter
  };

  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {100, 100}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {50, 50})
  ];
  subnodes[0].style.flexShrink = 1;
  subnodes[1].style.flexShrink = 1;

  static ASSizeRange kFixedWidth = {{150, 0}, {150, 100}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignCenterWithIndefiniteCrossDimension
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  ASDisplayNode *subnode1 = ASDisplayNodeWithBackgroundColor([UIColor redColor], {100, 100});
  
  ASDisplayNode *subnode2 = ASDisplayNodeWithBackgroundColor([UIColor blueColor], {50, 50});
  subnode2.style.alignSelf = ASStackLayoutAlignSelfCenter;

  NSArray<ASDisplayNode *> *subnodes = @[subnode1, subnode2];
  static ASSizeRange kFixedWidth = {{150, 0}, {150, INFINITY}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kFixedWidth subnodes:subnodes identifier:nil];
}

- (void)testAlignedStart
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStart
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);
  
  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedEnd
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsEnd
  };
  
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);
  
  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedCenter
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsCenter
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);
  
  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  static ASSizeRange kExactSize = {{300, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kExactSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchNoChildExceedsMin
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);

  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  static ASSizeRange kVariableSize = {{200, 200}, {300, 300}};
  // all children should be 200px wide
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testAlignedStretchOneChildExceedsMin
{
  ASStackLayoutSpecStyle style = {
    .direction = ASStackLayoutDirectionVertical,
    .justifyContent = ASStackLayoutJustifyContentCenter,
    .alignItems = ASStackLayoutAlignItemsStretch
  };

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({100, 70}, subnodes[1]);
  setCGSizeToNode({150, 90}, subnodes[2]);
  
  subnodes[0].style.spacingBefore = 0;
  subnodes[1].style.spacingBefore = 20;
  subnodes[2].style.spacingBefore = 30;

  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  // all children should be 150px wide
  [self testStackLayoutSpecWithStyle:style sizeRange:kVariableSize subnodes:subnodes identifier:nil];
}

- (void)testEmptyStack
{
  static ASSizeRange kVariableSize = {{50, 50}, {300, 300}};
  [self testStackLayoutSpecWithStyle:{} sizeRange:kVariableSize subnodes:@[] identifier:nil];
}

- (void)testFixedFlexBasisAppliedWhenFlexingItems
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  setCGSizeToNode({150, 150}, subnodes[1]);

  for (ASDisplayNode *subnode in subnodes) {
    subnode.style.flexGrow = 1;
    subnode.style.flexBasis = ASDimensionMakeWithPoints(10);
  }

  // width 300px; height 0-150px.
  static ASSizeRange kUnderflowSize = {{300, 0}, {300, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kUnderflowSize subnodes:subnodes identifier:@"underflow"];

  // width 200px; height 0-150px.
  static ASSizeRange kOverflowSize = {{200, 0}, {200, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kOverflowSize subnodes:subnodes identifier:@"overflow"];
}

- (void)testFractionalFlexBasisResolvesAgainstParentSize
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  for (ASDisplayNode *subnode in subnodes) {
    subnode.style.flexGrow = 1;
  }

  // This should override the intrinsic size of 50pts and instead compute to 50% = 100pts.
  // The result should be that the red box is twice as wide as the blue and gree boxes after flexing.
  subnodes[0].style.flexBasis = ASDimensionMakeWithFraction(0.5);

  static ASSizeRange kSize = {{200, 0}, {200, INFINITY}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testFixedFlexBasisOverridesIntrinsicSizeForNonFlexingChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodes();
  setCGSizeToNode({50, 50}, subnodes[0]);
  setCGSizeToNode({150, 150}, subnodes[1]);
  setCGSizeToNode({150, 50}, subnodes[2]);

  for (ASDisplayNode *subnode in subnodes) {
    subnode.style.flexBasis = ASDimensionMakeWithPoints(20);
  }
  
  static ASSizeRange kSize = {{300, 0}, {300, 150}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testCrossAxisStretchingOccursAfterStackAxisFlexing
{
  // If cross axis stretching occurred *before* flexing, then the blue child would be stretched to 3000 points tall.
  // Instead it should be stretched to 300 points tall, matching the red child and not overlapping the green inset.

  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor]),           // Inset background node
    ASDisplayNodeWithBackgroundColor([UIColor blueColor]),            // child1 of stack
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {500, 500})  // child2 of stack
  ];
  
  subnodes[1].style.width = ASDimensionMake(10);
  
  ASDisplayNode *child2 = subnodes[2];
  child2.style.flexGrow = 1;
  child2.style.flexShrink = 1;

  // If cross axis stretching occurred *before* flexing, then the blue child would be stretched to 3000 points tall.
  // Instead it should be stretched to 300 points tall, matching the red child and not overlapping the green inset.
  ASLayoutSpec *layoutSpec =
  [ASBackgroundLayoutSpec
   backgroundLayoutSpecWithChild:
   [ASInsetLayoutSpec
    insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10)
    child:
    [ASStackLayoutSpec
     stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
     spacing:0
     justifyContent:ASStackLayoutJustifyContentStart
     alignItems:ASStackLayoutAlignItemsStretch
     children:@[subnodes[1], child2]]
    ]
   background:subnodes[0]];

  static ASSizeRange kSize = {{300, 0}, {300, INFINITY}};
  [self testLayoutSpec:layoutSpec sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testPositiveViolationIsDistributedEquallyAmongFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  subnodes[0].style.flexGrow = 0;
  subnodes[2].style.flexGrow = 0;

  // In this scenario a width of 350 results in a positive violation of 200.
  // Due to each flexible subnode specifying a flex grow factor of 1 the violation will be distributed evenly.
  static ASSizeRange kSize = {{350, 350}, {350, 350}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testPositiveViolationIsDistributedProportionallyAmongFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};

  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize({50, 50}, 0);
  subnodes[0].style.flexGrow = 1;
  subnodes[1].style.flexGrow = 2;
  subnodes[2].style.flexGrow = 1;

  // In this scenario a width of 350 results in a positive violation of 200.
  // The first and third subnodes specify a flex grow factor of 1 and will flex by 50.
  // The second subnode specifies a flex grow factor of 2 and will flex by 100.
  static ASSizeRange kSize = {{350, 350}, {350, 350}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testPositiveViolationIsDistributedEquallyAmongGrowingAndShrinkingFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  
  const CGSize kSubnodeSize = {50, 50};
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize(kSubnodeSize, 0);
  subnodes = [subnodes arrayByAddingObject:ASDisplayNodeWithBackgroundColor([UIColor yellowColor], kSubnodeSize)];
  
  subnodes[0].style.flexShrink = 1;
  subnodes[1].style.flexGrow = 1;
  subnodes[2].style.flexShrink = 0;
  subnodes[3].style.flexGrow = 1;
  
  // In this scenario a width of 400 results in a positive violation of 200.
  // The first and third subnode specify a flex shrink factor of 1 and 0, respectively. They won't flex.
  // The second and fourth subnode specify a flex grow factor of 1 and will flex by 100.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testPositiveViolationIsDistributedProportionallyAmongGrowingAndShrinkingFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};
  
  const CGSize kSubnodeSize = {50, 50};
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize(kSubnodeSize, 0);
  subnodes = [subnodes arrayByAddingObject:ASDisplayNodeWithBackgroundColor([UIColor yellowColor], kSubnodeSize)];
  
  subnodes[0].style.flexShrink = 1;
  subnodes[1].style.flexGrow = 3;
  subnodes[2].style.flexShrink = 0;
  subnodes[3].style.flexGrow = 1;
  
  // In this scenario a width of 400 results in a positive violation of 200.
  // The first and third subnodes specify a flex shrink factor of 1 and 0, respectively. They won't flex.
  // The second child subnode specifies a flex grow factor of 3 and will flex by 150.
  // The fourth child subnode specifies a flex grow factor of 1 and will flex by 50.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testRemainingViolationIsAppliedProperlyToFirstFlexibleChild
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};
  
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], {50, 25}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {50, 0}),
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 100})
  ];

  subnodes[0].style.flexGrow = 0;
  subnodes[1].style.flexGrow = 1;
  subnodes[2].style.flexGrow = 1;
  
  // In this scenario a width of 300 results in a positive violation of 175.
  // The second and third subnodes specify a flex grow factor of 1 and will flex by 88 and 87, respectively.
  static ASSizeRange kSize = {{300, 300}, {300, 300}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNegativeViolationIsDistributedProportionallyBasedOnSizeAmongFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], {300, 50}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {100, 50}),
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {200, 50})
  ];
  
  subnodes[0].style.flexShrink = 1;
  subnodes[1].style.flexShrink = 0;
  subnodes[2].style.flexShrink = 1;

  // In this scenario a width of 400 results in a negative violation of 200.
  // The first and third subnodes specify a flex shrink factor of 1 and will flex by -120 and -80, respectively.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNegativeViolationIsDistributedProportionallyBasedOnSizeAndFlexFactorAmongFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};
  
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], {50, 300}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {50, 100}),
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 200})
  ];
  
  subnodes[0].style.flexShrink = 2;
  subnodes[1].style.flexShrink = 1;
  subnodes[2].style.flexShrink = 2;

  // In this scenario a width of 400 results in a negative violation of 200.
  // The first and third subnodes specify a flex shrink factor of 2 and will flex by -109 and -72, respectively.
  // The second subnode specifies a flex shrink factor of 1 and will flex by -18.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNegativeViolationIsDistributedProportionallyBasedOnSizeAmongGrowingAndShrinkingFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  
  const CGSize kSubnodeSize = {150, 50};
  NSArray<ASDisplayNode *> *subnodes = defaultSubnodesWithSameSize(kSubnodeSize, 0);
  subnodes = [subnodes arrayByAddingObject:ASDisplayNodeWithBackgroundColor([UIColor yellowColor], kSubnodeSize)];
  
  subnodes[0].style.flexGrow = 1;
  subnodes[1].style.flexShrink = 1;
  subnodes[2].style.flexGrow = 0;
  subnodes[3].style.flexShrink = 1;
  
  // In this scenario a width of 400 results in a negative violation of 200.
  // The first and third subnodes specify a flex grow factor of 1 and 0, respectively. They won't flex.
  // The second and fourth subnodes specify a flex grow factor of 1 and will flex by -100.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNegativeViolationIsDistributedProportionallyBasedOnSizeAndFlexFactorAmongGrowingAndShrinkingFlexibleChildren
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionVertical};
  
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], {50, 150}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {50, 100}),
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 150}),
    ASDisplayNodeWithBackgroundColor([UIColor yellowColor], {50, 200})
  ];
  
  subnodes[0].style.flexGrow = 1;
  subnodes[1].style.flexShrink = 1;
  subnodes[2].style.flexGrow = 0;
  subnodes[3].style.flexShrink = 3;
  
  // In this scenario a width of 400 results in a negative violation of 200.
  // The first and third subnodes specify a flex grow factor of 1 and 0, respectively. They won't flex.
  // The second subnode specifies a flex grow factor of 1 and will flex by -28.
  // The fourth subnode specifies a flex grow factor of 3 and will flex by -171.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNegativeViolationIsDistributedProportionallyBasedOnSizeAndFlexFactorDoesNotShrinkToZeroWidth
{
  ASStackLayoutSpecStyle style = {.direction = ASStackLayoutDirectionHorizontal};
  
  NSArray<ASDisplayNode *> *subnodes = @[
    ASDisplayNodeWithBackgroundColor([UIColor greenColor], {300, 50}),
    ASDisplayNodeWithBackgroundColor([UIColor blueColor], {100, 50}),
    ASDisplayNodeWithBackgroundColor([UIColor redColor], {200, 50})
  ];
  
  subnodes[0].style.flexShrink = 1;
  subnodes[1].style.flexShrink = 2;
  subnodes[2].style.flexShrink = 1;
  
  // In this scenario a width of 400 results in a negative violation of 200.
  // The first and third subnodes specify a flex shrink factor of 1 and will flex by 50.
  // The second subnode specifies a flex shrink factor of 2 and will flex by -57. It will have a width of 43.
  static ASSizeRange kSize = {{400, 400}, {400, 400}};
  [self testStackLayoutSpecWithStyle:style sizeRange:kSize subnodes:subnodes identifier:nil];
}

- (void)testNestedStackLayoutStretchDoesNotViolateWidth
{
  ASStackLayoutSpec *stackLayoutSpec = [[ASStackLayoutSpec alloc] init]; // Default direction is horizontal
  stackLayoutSpec.direction = ASStackLayoutDirectionHorizontal;
  stackLayoutSpec.alignItems = ASStackLayoutAlignItemsStretch;
  [stackLayoutSpec.style setSizeWithCGSize:{100, 100}];
  
  ASDisplayNode *child = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  stackLayoutSpec.children = @[child];
  
  static ASSizeRange kSize = {{0, 0}, {300, INFINITY}};
  [self testStackLayoutSpec:stackLayoutSpec sizeRange:kSize subnodes:@[child] identifier:nil];
}

- (void)testHorizontalAndVerticalAlignments
{
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal itemsHorizontalAlignment:ASHorizontalAlignmentLeft itemsVerticalAlignment:ASVerticalAlignmentTop identifier:@"horizontalTopLeft"];
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal itemsHorizontalAlignment:ASHorizontalAlignmentMiddle itemsVerticalAlignment:ASVerticalAlignmentCenter identifier:@"horizontalCenter"];
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal itemsHorizontalAlignment:ASHorizontalAlignmentRight itemsVerticalAlignment:ASVerticalAlignmentBottom identifier:@"horizontalBottomRight"];
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionVertical itemsHorizontalAlignment:ASHorizontalAlignmentLeft itemsVerticalAlignment:ASVerticalAlignmentTop identifier:@"verticalTopLeft"];
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionVertical itemsHorizontalAlignment:ASHorizontalAlignmentMiddle itemsVerticalAlignment:ASVerticalAlignmentCenter identifier:@"verticalCenter"];
  [self testStackLayoutSpecWithDirection:ASStackLayoutDirectionVertical itemsHorizontalAlignment:ASHorizontalAlignmentRight itemsVerticalAlignment:ASVerticalAlignmentBottom identifier:@"verticalBottomRight"];
}

- (void)testDirectionChangeAfterSettingHorizontalAndVerticalAlignments
{
  ASStackLayoutSpec *stackLayoutSpec = [[ASStackLayoutSpec alloc] init]; // Default direction is horizontal
  stackLayoutSpec.horizontalAlignment = ASHorizontalAlignmentRight;
  stackLayoutSpec.verticalAlignment = ASVerticalAlignmentCenter;
  XCTAssertEqual(stackLayoutSpec.alignItems, ASStackLayoutAlignItemsCenter);
  XCTAssertEqual(stackLayoutSpec.justifyContent, ASStackLayoutJustifyContentEnd);
  
  stackLayoutSpec.direction = ASStackLayoutDirectionVertical;
  XCTAssertEqual(stackLayoutSpec.alignItems, ASStackLayoutAlignItemsEnd);
  XCTAssertEqual(stackLayoutSpec.justifyContent, ASStackLayoutJustifyContentCenter);
}

- (void)testAlignItemsAndJustifyContentRestrictionsIfHorizontalAndVerticalAlignmentsAreUsed
{
  ASStackLayoutSpec *stackLayoutSpec = [[ASStackLayoutSpec alloc] init];

  // No assertions should be thrown here because alignments are not used
  stackLayoutSpec.alignItems = ASStackLayoutAlignItemsEnd;
  stackLayoutSpec.justifyContent = ASStackLayoutJustifyContentEnd;

  // Set alignments and assert that assertions are thrown
  stackLayoutSpec.horizontalAlignment = ASHorizontalAlignmentMiddle;
  stackLayoutSpec.verticalAlignment = ASVerticalAlignmentCenter;
  XCTAssertThrows(stackLayoutSpec.alignItems = ASStackLayoutAlignItemsEnd);
  XCTAssertThrows(stackLayoutSpec.justifyContent = ASStackLayoutJustifyContentEnd);

  // Unset alignments. alignItems and justifyContent should not be changed
  stackLayoutSpec.horizontalAlignment = ASHorizontalAlignmentNone;
  stackLayoutSpec.verticalAlignment = ASVerticalAlignmentNone;
  XCTAssertEqual(stackLayoutSpec.alignItems, ASStackLayoutAlignItemsCenter);
  XCTAssertEqual(stackLayoutSpec.justifyContent, ASStackLayoutJustifyContentCenter);

  // Now that alignments are none, setting alignItems and justifyContent should be allowed again
  stackLayoutSpec.alignItems = ASStackLayoutAlignItemsEnd;
  stackLayoutSpec.justifyContent = ASStackLayoutJustifyContentEnd;
  XCTAssertEqual(stackLayoutSpec.alignItems, ASStackLayoutAlignItemsEnd);
  XCTAssertEqual(stackLayoutSpec.justifyContent, ASStackLayoutJustifyContentEnd);
}

@end
