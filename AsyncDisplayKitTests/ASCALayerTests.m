//
//  ASCALayerTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/2/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>
#import <OCMock/NSInvocation+OCMAdditions.h>

/**
 * Tests that confirm what we know about Core Animation behavior.
 *
 * These tests are not run during the normal test action. You can run them yourself
 * to investigate and confirm CA behavior.
 */
@interface ASCALayerTests : XCTestCase

@end

#define DeclareLayerAndSublayer() \
  CALayer *realSublayer = [CALayer layer]; \
  id layer = [OCMockObject partialMockForObject:[CALayer layer]]; \
  id sublayer = [OCMockObject partialMockForObject:realSublayer]; \
  [layer addSublayer:realSublayer];

@implementation ASCALayerTests

- (void)testThatLayerBeginsWithCleanLayout
{
  XCTAssertFalse([CALayer layer].needsLayout);
}

- (void)testThatAddingSublayersDirtysLayout
{
  CALayer *layer = [CALayer layer];
  [layer addSublayer:[CALayer layer]];
  XCTAssertTrue([layer needsLayout]);
}

- (void)testThatRemovingSublayersDirtysLayout
{
  DeclareLayerAndSublayer();
  [layer layoutIfNeeded];
  XCTAssertFalse([layer needsLayout]);
  [sublayer removeFromSuperlayer];
  XCTAssertTrue([layer needsLayout]);
}

- (void)testDirtySublayerLayoutDoesntDirtySuperlayer
{
  DeclareLayerAndSublayer();
  [layer layoutIfNeeded];

  // Dirtying sublayer doesn't dirty superlayer.
  [sublayer setNeedsLayout];
  XCTAssertTrue([sublayer needsLayout]);
  XCTAssertFalse([layer needsLayout]);
  [[[sublayer expect] andForwardToRealObject] layoutSublayers];
  // NOTE: We specifically don't expect layer to get -layoutSublayers
  [sublayer layoutIfNeeded];
  [sublayer verify];
  [layer verify];
}

- (void)testDirtySuperlayerLayoutDoesntDirtySublayerLayout
{
  DeclareLayerAndSublayer();
  [layer layoutIfNeeded];

  // Dirtying superlayer doesn't dirty sublayer.
  [layer setNeedsLayout];
  XCTAssertTrue([layer needsLayout]);
  XCTAssertFalse([sublayer needsLayout]);
  [[[layer expect] andForwardToRealObject] layoutSublayers];
  // NOTE: We specifically don't expect sublayer to get -layoutSublayers
  [layer layoutIfNeeded];
  [sublayer verify];
  [layer verify];
}

- (void)testDirtyHierarchyIsLaidOutTopDown
{
  DeclareLayerAndSublayer();
  [sublayer setNeedsLayout];

  XCTAssertTrue([layer needsLayout]);
  XCTAssertTrue([sublayer needsLayout]);

  __block BOOL superlayerLaidOut = NO;
  [[[[layer expect] andDo:^(NSInvocation *i) {
    superlayerLaidOut = YES;
  }] andForwardToRealObject] layoutSublayers];

  [[[[sublayer expect] andDo:^(NSInvocation *i) {
    XCTAssertTrue(superlayerLaidOut);
  }] andForwardToRealObject] layoutSublayers];

  [layer layoutIfNeeded];
  [sublayer verify];
  [layer verify];
}

@end
