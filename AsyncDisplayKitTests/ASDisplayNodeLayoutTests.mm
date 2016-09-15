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
#import "ASDisplayNode+FrameworkPrivate.h"

@interface ASDisplayNodeLayoutTests : XCTestCase
@end

@implementation ASDisplayNodeLayoutTests

- (void)testMeasureOnLayoutIfNotHappenedBefore
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASStaticSizeDisplayNode *displayNode = [ASStaticSizeDisplayNode new];
  displayNode.staticSize  = nodeSize;
  
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
  
  XCTAssertThrows([displayNode measure:CGSizeMake(100, 100)], @"Should throw if subnode was added in layoutSpecThatFits:");
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
  
  XCTAssertThrows([displayNode measure:CGSizeMake(100, 100)], @"Should throw if subnodes where modified in layoutSpecThatFits:");
}
#endif

- (void)testMeasureOnLayoutIfNotHappenedBeforeNoRemeasureForSameBounds
{
  CGSize nodeSize = CGSizeMake(100, 100);
  
  ASStaticSizeDisplayNode *displayNode = [ASStaticSizeDisplayNode new];
  displayNode.staticSize  = nodeSize;
  
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
  
  [displayNode measureWithSizeRange:ASSizeRangeMake(nodeSize, nodeSize)];
  XCTAssertEqual(numberOfLayoutSpecThatFitsCalls, 1, @"Should not remeasure with same bounds");
}

@end
