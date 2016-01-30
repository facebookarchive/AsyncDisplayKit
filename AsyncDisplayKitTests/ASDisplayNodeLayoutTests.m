//
//  ASDisplayNodeLayoutTests.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/16/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface _ASInterfaceHelper : NSObject <ASDisplayNodeInterfaceDelegate>

@property (copy, nonatomic, nullable) ASLayout * _Nullable (^layoutThatFits)(ASSizeRange constrainedSize);
@property (copy, nonatomic, nullable) ASLayoutSpec * _Nullable (^layoutSpecThatFits)(ASSizeRange constrainedSize);

@end

@implementation _ASInterfaceHelper

- (ASLayout * _Nullable)displayNode:(ASDisplayNode * _Nonnull)displayNode layoutThatFits:(ASSizeRange)constrainedSize
{
  return self.layoutThatFits ? self.layoutThatFits(constrainedSize) : nil;
}

- (ASLayoutSpec * _Nullable)displayNode:(ASDisplayNode * _Nonnull)displayNode layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return self.layoutSpecThatFits ? self.layoutSpecThatFits(constrainedSize) : nil;
}

@end

@interface ASDisplayNodeLayoutTests : XCTestCase

@property (strong, nonatomic, nonnull) _ASInterfaceHelper *interfaceHelper;

@end

@implementation ASDisplayNodeLayoutTests

- (void)setUp {
  [super setUp];
  self.interfaceHelper = [[_ASInterfaceHelper alloc] init];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testLayoutFromInterfaceDelegate
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.interfaceDelegate = self.interfaceHelper;
  self.interfaceHelper.layoutThatFits = ^ ASLayout * _Nullable (ASSizeRange constrainedSize) {
    return [ASLayout layoutWithLayoutableObject:node size:constrainedSize.max];
  };
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeMake(1000.0, 1000.0), CGSizeMake(1000.0, 1000.0))];
  XCTAssertEqual(node.calculatedSize.height, 1000.0, @"should equal the calculated height of the layout spec");
  XCTAssertEqual(node.calculatedSize.width, 1000.0, @"should equal the calculated width of the layout spec");
}

- (void)testLayoutSpecFromInterfaceDelegate
{
  self.interfaceHelper.layoutSpecThatFits = ^ ASLayoutSpec * _Nullable (ASSizeRange constrainedSize) {
    return [[ASStaticLayoutSpec alloc] init];
  };
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.interfaceDelegate = self.interfaceHelper;
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeMake(1000.0, 1000.0), CGSizeMake(1000.0, 1000.0))];
  XCTAssertEqual(node.calculatedSize.height, 1000.0, @"should equal the calculated height of the layout spec");
  XCTAssertEqual(node.calculatedSize.width, 1000.0, @"should equal the calculated width of the layout spec");
}

- (void)testLayoutFromInterfaceDelegateOverride
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.interfaceDelegate = self.interfaceHelper;
  XCTestExpectation *expectation = [self expectationWithDescription:@"should default to the layout implementation when both are implemented"];
  self.interfaceHelper.layoutThatFits = ^ ASLayout * _Nullable (ASSizeRange constrainedSize) {
    [expectation fulfill];
    return [ASLayout layoutWithLayoutableObject:node size:constrainedSize.max];
  };
  self.interfaceHelper.layoutSpecThatFits = ^ ASLayoutSpec * _Nullable (ASSizeRange constrainedSize) {
    return [[ASStaticLayoutSpec alloc] init];
  };
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeMake(1000.0, 1000.0), CGSizeMake(1000.0, 1000.0))];
  [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

@end
