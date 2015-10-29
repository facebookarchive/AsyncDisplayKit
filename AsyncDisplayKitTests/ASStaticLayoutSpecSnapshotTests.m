//
//  ASStaticLayoutSpecSnapshotTests.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 18/10/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import "ASStaticLayoutSpec.h"
#import "ASBackgroundLayoutSpec.h"

@interface ASStaticLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASStaticLayoutSpecSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testSizingBehaviour
{
  [self testWithSizeRange:ASSizeRangeMake(CGSizeMake(150, 200), CGSizeMake(FLT_MAX, FLT_MAX))
               identifier:@"underflowChildren"];
  [self testWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(50, 100))
               identifier:@"overflowChildren"];
  // Expect the spec to wrap its content because children sizes are between constrained size
  [self testWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(FLT_MAX / 2, FLT_MAX / 2))
               identifier:@"wrappedChildren"];
}

- (void)testChildrenMeasuredWithAutoMaxSize
{
  ASStaticSizeDisplayNode *firstChild = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  firstChild.layoutPosition = CGPointMake(0, 0);
  firstChild.staticSize = CGSizeMake(50, 50);
  
  ASStaticSizeDisplayNode *secondChild = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  secondChild.layoutPosition = CGPointMake(10, 60);
  secondChild.staticSize = CGSizeMake(100, 100);

  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeMake(10, 10), CGSizeMake(110, 160));
  [self testWithChildren:@[firstChild, secondChild] sizeRange:sizeRange identifier:nil];
  
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(firstChild.constrainedSizeForCalculatedLayout,
                                            ASSizeRangeMake(CGSizeZero, sizeRange.max)));
  CGSize secondChildMaxSize = CGSizeMake(sizeRange.max.width - secondChild.layoutPosition.x,
                                         sizeRange.max.height - secondChild.layoutPosition.y);
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(secondChild.constrainedSizeForCalculatedLayout,
                                            ASSizeRangeMake(CGSizeZero, secondChildMaxSize)));
}

- (void)testWithSizeRange:(ASSizeRange)sizeRange identifier:(NSString *)identifier
{
  ASDisplayNode *firstChild = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  firstChild.layoutPosition = CGPointMake(0, 0);
  firstChild.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(50, 50));
  
  
  ASDisplayNode *secondChild = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  secondChild.layoutPosition = CGPointMake(0, 50);
  secondChild.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(CGSizeMake(100, 100));
  
  [self testWithChildren:@[firstChild, secondChild] sizeRange:sizeRange identifier:identifier];
}

- (void)testWithChildren:(NSArray *)children sizeRange:(ASSizeRange)sizeRange identifier:(NSString *)identifier
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor whiteColor]);

  NSMutableArray *subnodes = [NSMutableArray arrayWithArray:children];
  [subnodes insertObject:backgroundNode atIndex:0];

  ASStaticLayoutSpec *staticLayoutSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:children];
  ASLayoutSpec *layoutSpec = [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:staticLayoutSpec
                                                                        background:backgroundNode];
  
  [self testLayoutSpec:layoutSpec sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

@end
