/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <XCTest/XCTest.h>

#import "ASLayoutNode.h"


@interface ASLayoutNodeSizeTests : XCTestCase
@end

@implementation ASLayoutNodeSizeTests

- (void)testResolvingSizeWithAutoInAllFieldsReturnsUnconstrainedRange
{
  ASLayoutNodeSize s;
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {500, 300});
  XCTAssertEqual(r.min.width, 0.f, @"Expected no min width");
  XCTAssertEqual(r.max.width, INFINITY, @"Expected no max width");
  XCTAssertEqual(r.min.height, 0.f, @"Expected no min height");
  XCTAssertEqual(r.max.height, INFINITY, @"Expected no max height");
}

- (void)testPercentageWidthIsResolvedAgainstParentDimension
{
  ASLayoutNodeSize s = {.width = ASRelativeDimensionMakeWithPercent(1.0)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {500, 300});
  XCTAssertEqual(r.min.width, 500.0f, @"Expected min of resolved range to match");
  XCTAssertEqual(r.max.width, 500.0f, @"Expected max of resolved range to match");
}

- (void)testMaxSizeClampsLayoutNodeSize
{
  ASLayoutNodeSize s = {.width = ASRelativeDimensionMakeWithPercent(1.0), .maxWidth = ASRelativeDimensionMakeWithPoints(300)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {500, 300});
  XCTAssertEqual(r.min.width, 300.0f, @"Expected max-size to clamp the width to exactly 300 pts");
  XCTAssertEqual(r.max.width, 300.0f, @"Expected max-size to clamp the width to exactly 300 pts");
}

- (void)testMinSizeOverridesMaxSizeWhenTheyConflict
{
  // Min-size overriding max-size matches CSS.
  ASLayoutNodeSize s = {.minWidth = ASRelativeDimensionMakeWithPercent(0.5), .maxWidth = ASRelativeDimensionMakeWithPoints(300)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {800, 300});
  XCTAssertEqual(r.min.width, 400.0f, @"Expected min-size to override max-size");
  XCTAssertEqual(r.max.width, 400.0f, @"Expected min-size to override max-size");
}

- (void)testMinSizeAloneResultsInRangeUnconstrainedToInfinity
{
  ASLayoutNodeSize s = {.minWidth = ASRelativeDimensionMakeWithPoints(100)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {800, 300});
  XCTAssertEqual(r.min.width, 100.0f, @"Expected min width to be passed through");
  XCTAssertEqual(r.max.width, INFINITY, @"Expected max width to be infinity since no maxWidth was specified");
}

- (void)testMaxSizeAloneResultsInRangeUnconstrainedFromZero
{
  ASLayoutNodeSize s = {.maxWidth = ASRelativeDimensionMakeWithPoints(100)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {800, 300});
  XCTAssertEqual(r.min.width, 0.0f, @"Expected min width to be zero");
  XCTAssertEqual(r.max.width, 100.0f, @"Expected max width to be passed through");
}

- (void)testMinSizeAndMaxSizeResolveToARangeWhenTheyAreNotInConflict
{
  ASLayoutNodeSize s = {.minWidth = ASRelativeDimensionMakeWithPoints(100), .maxWidth = ASRelativeDimensionMakeWithPoints(300)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {800, 300});
  XCTAssertEqual(r.min.width, 100.0f, @"Expected min-size to be passed to size range");
  XCTAssertEqual(r.max.width, 300.0f, @"Expected max-size to be passed to size range");
}

- (void)testWhenWidthFallsBetweenMinAndMaxWidthsItReturnsARangeWithExactlyThatWidth
{
  ASLayoutNodeSize s = {.minWidth = ASRelativeDimensionMakeWithPoints(100), .width = ASRelativeDimensionMakeWithPoints(200), .maxWidth = ASRelativeDimensionMakeWithPoints(300)};
  ASSizeRange r = ASLayoutNodeSizeResolve(s, {800, 300});
  XCTAssertEqual(r.min.width, 200.0f, @"Expected min-size to be width");
  XCTAssertEqual(r.max.width, 200.0f, @"Expected max-size to be width");
}

@end
