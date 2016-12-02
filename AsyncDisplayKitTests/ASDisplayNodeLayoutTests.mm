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

@interface DisplayNode : ASDisplayNode

@end

@implementation DisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASTextNode *someOtherNode = [ASTextNode new];
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
}
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

- (void)testThatLayoutElementCreatedInLayoutSpecThatFitsDoesNotGetDeallocated
{
  ASDisplayNode *displayNode = [DisplayNode new];
  displayNode.automaticallyManagesSubnodes = YES;
  
  //[displayNode addSubnode:someOtherNode];
  /*displayNode.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    ASTextNode *someOtherNode = [ASTextNode new];
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsZero child:someOtherNode];
  };*/
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Query timed out."];
  //CGSize s = CGSizeZero;
  displayNode.frame = CGRectMake(0, 0, 300, 300);
  [displayNode view];
  
  __unused CGSize s = CGSizeZero;
  
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    //ASLayout *layout
    
    @autoreleasepool {
      __unused CGSize s = [displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX))].size;
      //s = [displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(100, CGFLOAT_MAX))].size;
      //[displayNode setNeedsLayout];
      //s = [displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(200, CGFLOAT_MAX))].size;
      //[displayNode setNeedsLayout];
      s = [displayNode layoutThatFits:ASSizeRangeMake(CGSizeMake(300, 300), CGSizeMake(300, 300))].size;
      //[displayNode setNeedsLayout];
    }

    
    dispatch_async(dispatch_get_main_queue(), ^{
      
      //__unused CGSize s = [displayNode layoutThatFits:ASSizeRangeMake(CGSizeZero, CGSizeMake(CGFLOAT_MAX, 200))].size;
      
      //[displayNode setNeedsLayout];
      [displayNode.view layoutIfNeeded];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [expectation fulfill];
      });
    });
  });
  
  
  //[displayNode view];
  
  /*dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    
    //displayNode.frame = CGRectMake(0, 0, 100, 100);
    [displayNode setNeedsLayout];
    [displayNode.view layoutIfNeeded];
    
    
    // First layout pass
    //displayNode.frame = CGRectMake(0, 0, layout.size.width, layout.size.height);
    //[displayNode setNeedsLayout];
    //[displayNode.view layoutIfNeeded];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [displayNode transitionLayoutWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(80, 80)) animated:NO shouldMeasureAsync:NO measurementCompletion:nil];
      [expectation fulfill];
    });  
  });*/
  
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      NSLog(@"Error: %@", error);
    }
  }];
  //XCTAssertNoThrow([displayNode layoutThatFits:ASSizeRangeMake(CGSizeMake(0, FLT_MAX))]);
}

@end
