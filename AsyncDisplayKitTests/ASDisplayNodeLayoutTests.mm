//
//  ASDisplayNodeLayoutTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASXCTExtensions.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "ASLayoutSpecSnapshotTestsHelper.h"
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>

@interface ASLayout ()
- (ASLayout *)filteredNodeLayoutTree;
@end

@interface ASDisplayNodeLayoutTests : XCTestCase
@end

@implementation ASDisplayNodeLayoutTests

- (void)testMeasureOnLayoutIfNotHappenedBefore
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  displayNode.style.width = ASDimensionMake(100);
  displayNode.style.height = ASDimensionMake(100);
  
  // Use a button node in here as ASButtonNode uses layoutSpecThatFits:
  ASButtonNode *buttonNode = [ASButtonNode new];
  [displayNode addSubnode:buttonNode];
  
  displayNode.frame = {.size = nodeSize};
  buttonNode.frame = {.size = nodeSize};
  
  ASXCTAssertEqualSizes(displayNode.calculatedSize, CGSizeZero, @"Calculated size before measurement and layout should be 0");
  ASXCTAssertEqualSizes(buttonNode.calculatedSize, CGSizeZero, @"Calculated size before measurement and layout should be 0");
  
  // Trigger view creation and layout pass without a manual measure: call before so the automatic measurement
  // pass will trigger in the layout pass
  [displayNode.view layoutIfNeeded];
  
  ASXCTAssertEqualSizes(displayNode.calculatedSize, nodeSize, @"Automatic measurement pass should have happened in layout pass");
  ASXCTAssertEqualSizes(buttonNode.calculatedSize, nodeSize, @"Automatic measurement pass should have happened in layout pass");
}

#if DEBUG
- (void)testNotAllowAddingSubnodesInLayoutSpecThatFits
{
  ASDisplayNode *displayNode = [ASDisplayNode new];
  ASDisplayNode *someOtherNode = [ASDisplayNode new];
  
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    [node addSubnode:someOtherNode];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
  };
  
  XCTAssertThrows([displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 100))], @"Should throw if subnode was added in layoutSpecThatFits:");
}

- (void)testNotAllowModifyingSubnodesInLayoutSpecThatFits
{
  ASDisplayNode *displayNode = [ASDisplayNode new];
  ASDisplayNode *someOtherNode = [ASDisplayNode new];
  
  [displayNode addSubnode:someOtherNode];
  
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    [someOtherNode removeFromSupernode];
    [node addSubnode:[ASDisplayNode new]];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
  };
  
  XCTAssertThrows([displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, 100))], @"Should throw if subnodes where modified in layoutSpecThatFits:");
}
#endif

- (void)testMeasureOnLayoutIfNotHappenedBeforeNoRemeasureForSameBounds
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASDisplayNode *displayNode = [ASDisplayNode new];
  displayNode.style.width = ASDimensionMake(nodeSize.width);
  displayNode.style.height = ASDimensionMake(nodeSize.height);
  
  ASButtonNode *buttonNode = [ASButtonNode new];
  [displayNode addSubnode:buttonNode];
  
  __block size_t numberOfLayoutSpecThatFitsCalls = 0;
  displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    __sync_fetch_and_add(&numberOfLayoutSpecThatFitsCalls, 1);
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:buttonNode];
  };
  
  displayNode.frame = {.size = nodeSize};
  
  // Trigger initial layout pass without a measurement pass before
  [displayNode.view layoutIfNeeded];
  XCTAssertEqual(numberOfLayoutSpecThatFitsCalls, 1, @"Should measure during layout if not measured");
  
  [displayNode layoutThatFits:ASSizeRangeMake(nodeSize, nodeSize)];
  XCTAssertEqual(numberOfLayoutSpecThatFitsCalls, 1, @"Should not remeasure with same bounds");
}

- (void)testThatLayoutWithInvalidSizeCausesException
{
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.layoutSpecBlock = ^ASLayoutSpec *(ASDisplayNode *node, ASSizeRange constrainedSize) {
    return [ASWrapperLayoutSpec wrapperWithLayoutElement:displayNode];
  };
  
  XCTAssertThrows([node layoutThatFits:ASSizeRangeMake(CGSizeMake(0, FLT_MAX))]);
}

- (void)testThatLayoutCreatedWithInvalidSizeCausesException
{
  ASDisplayNode *displayNode = [[ASDisplayNode alloc] init];
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(FLT_MAX, FLT_MAX)]);
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)]);
  XCTAssertThrows([ASLayout layoutWithLayoutElement:displayNode size:CGSizeMake(INFINITY, INFINITY)]);
}

- (void)testThatLayoutElementCreatedInLayoutSpecThatFitsDoNotGetDeallocated
{
  const CGSize kSize = CGSizeMake(300, 300);
  
  ASDisplayNode *subNode = [[ASDisplayNode alloc] init];
  subNode.automaticallyManagesSubnodes = YES;
  subNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASTextNode *textNode = [ASTextNode new];
    textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Test Test Test Test Test Test Test Test"];
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:textNode];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:insetSpec];
  };
  
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  rootNode.automaticallyManagesSubnodes = YES;
  rootNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASTextNode *textNode = [ASTextNode new];
    textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Test Test Test Test Test"];
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:textNode];
    
    return [ASStackLayoutSpec
            stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
            spacing:0.0
            justifyContent:ASStackLayoutJustifyContentStart
            alignItems:ASStackLayoutAlignItemsStretch
            children:@[insetSpec, subNode]];
  };

  rootNode.frame = CGRectMake(0, 0, kSize.width, kSize.height);
  [rootNode view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Execute measure and layout pass"];
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    [rootNode layoutThatFits:ASSizeRangeMake(kSize)];
    
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertNoThrow([rootNode.view layoutIfNeeded]);
      [expectation fulfill];
    });
  });
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      XCTFail(@"Expectation failed: %@", error);
    }
  }];
}

- (void)testThatFilteredNodeLayoutTreeIsWorking
{
  static CGSize kSize = CGSizeMake(100, 100);
  static CGPoint kPosition = CGPointMake(10, 10);
  
  ASDisplayNode *subnodeOne = [[ASDisplayNode alloc] init];
  ASLayout *subnodeOneLayout = [ASLayout layoutWithLayoutElement:subnodeOne size:kSize position:kPosition sublayouts:@[]];
  
  ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:subnodeOne];
  ASLayout *insetSpecLayout = [ASLayout layoutWithLayoutElement:insetSpec size:kSize position:kPosition sublayouts:@[subnodeOneLayout]];
  
  ASDisplayNode *subnodeTwo = [[ASDisplayNode alloc] init];
  ASLayout *subnodeTwoLayout = [ASLayout layoutWithLayoutElement:subnodeTwo size:kSize position:kPosition sublayouts:@[]];
  
  ASAbsoluteLayoutSpec *absoluteSpec = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[insetSpec, subnodeTwo]];
  ASLayout *absoluteSpecLayout = [ASLayout layoutWithLayoutElement:absoluteSpec size:kSize position:kPosition sublayouts:@[insetSpecLayout, subnodeTwoLayout]];
  
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  ASLayout *rootNodeLayout = [ASLayout layoutWithLayoutElement:rootNode size:kSize sublayouts:@[absoluteSpecLayout]];

  NSArray<ASDisplayNode *> *subnodes = @[subnodeOne, subnodeTwo];
  ASLayout *layout = [rootNodeLayout filteredNodeLayoutTree];
  XCTAssertEqual(@(subnodes.count), @(layout.sublayouts.count), @"Initial filteredNodeLayoutTree is not working");
  for (int i = 0; i < subnodes.count; i++) {
    XCTAssertEqual(subnodes[i], layout.sublayouts[i].layoutElement, @"Initial filteredNodeLayoutTree is not working");
  }
  
  layout = [rootNodeLayout filteredNodeLayoutTree];
  XCTAssertEqual(@(subnodes.count), @(layout.sublayouts.count), @"Calling filteredNodeLayoutTree multiple times is not working");
  for (int i = 0; i < subnodes.count; i++) {
    XCTAssertEqual(subnodes[i], layout.sublayouts[i].layoutElement, @"Calling filteredNodeLayoutTree multiple times is not working");
  }
}

- (void)testThatFilteredNodeLayoutTreeIsWorkingWithDisplayNodes
{
  static CGSize kSize = CGSizeMake(100, 100);
  
  ASDisplayNode *subnodeOne = [[ASDisplayNode alloc] init];
  ASDisplayNode *subnodeTwo = [[ASDisplayNode alloc] init];
  NSArray<ASDisplayNode *> *subnodes = @[subnodeOne, subnodeTwo];
  
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  rootNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:subnodeOne];
    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[insetSpec, subnodeTwo]];
  };
  
  // Initial layout and creating of pending layout
  ASLayout *initialLayout = [rootNode layoutThatFits:ASSizeRangeMake(kSize)];
  XCTAssertEqual(initialLayout.layoutElement, rootNode);
  for (int i = 0; i < initialLayout.sublayouts.count; i++) {
    XCTAssertEqual(subnodes[i], initialLayout.sublayouts[i].layoutElement, @"Initial filtering or node layout tree is wrong");
  }
  
  // Multiple calls to filteredNodeLayoutTree
  ASLayout *layout = [initialLayout filteredNodeLayoutTree];
  for (int i = 0; i < layout.sublayouts.count; i++) {
    XCTAssertEqual(subnodes[i], layout.sublayouts[i].layoutElement, @"Calling filteredNodeLayoutTree again on a layout should return the same result");
  }
  
  // Force apply pending layout
  rootNode.frame = CGRectMake(0, 0, initialLayout.size.width, initialLayout.size.height);
  [rootNode.view layoutIfNeeded];
  
  // Check if cached layout that was returned still gives the same output
  layout = [rootNode layoutThatFits:ASSizeRangeMake(kSize)];
  XCTAssertEqual(layout.layoutElement, rootNode);
  XCTAssertEqual(layout, initialLayout);
  for (int i = 0; i < layout.sublayouts.count; i++) {
    XCTAssertEqual(subnodes[i], layout.sublayouts[i].layoutElement, @"Calling filteredNodeLayoutTree on cached layout will not return same result");
  }
}

- (void)testThatFilteredNodeLayoutTreeIsWorkingWithReusingALayout
{
  static CGSize kSize = CGSizeMake(100, 100);
  static CGPoint kPoint = CGPointMake(100, 100);
  
  ASDisplayNode *subnodeOne = [[ASDisplayNode alloc] init];
  ASDisplayNode *subnodeTwo = [[ASDisplayNode alloc] init];
  NSArray<ASDisplayNode *> *subnodes = @[subnodeOne, subnodeTwo];
  
  ASDisplayNode *rootNode = [[ASDisplayNode alloc] init];
  rootNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:subnodeOne];
    return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[insetSpec, subnodeTwo]];
  };
  
  // Initial Layout
  ASLayout *initialLayout = [rootNode layoutThatFits:ASSizeRangeMake(kSize)];
  XCTAssertEqual(initialLayout.layoutElement, rootNode);
  for (int i = 0; i < initialLayout.sublayouts.count; i++) {
    XCTAssertEqual(subnodes[i], initialLayout.sublayouts[i].layoutElement, @"Initial filtering or node layout tree is wrong");
  }
  
  // Reuse the first layout in another tree
  ASLayout *layoutToReuse = initialLayout.sublayouts[0];
  
  ASDisplayNode *subnodeThree = [[ASDisplayNode alloc] init];
  ASLayout *subnodeThreeLayout = [ASLayout layoutWithLayoutElement:subnodeThree size:kSize position:kPoint sublayouts:@[]];
  
  // Manually create layout tree to include the layout we gonna reuse
  ASDisplayNode *rootNodeTwo = [[ASDisplayNode alloc] init];
  NSArray *rootNodeTwoLayouts = @[subnodeThreeLayout, layoutToReuse];
  ASLayout *rootNodeTwoLayout = [ASLayout layoutWithLayoutElement:rootNodeTwo size:kSize position:kPoint sublayouts:rootNodeTwoLayouts];
  
  // Check if layout element we reused is in filtered layout
  ASLayout *filteredLayout = [rootNodeTwoLayout filteredNodeLayoutTree];
  XCTAssertTrue(filteredLayout.sublayouts.count == 2, @"Filtered layout should have two sublayouts");
  XCTAssertEqual(filteredLayout.sublayouts[1].layoutElement, layoutToReuse.layoutElement, @"Filter layout should include the reused layout element");
}

@end
