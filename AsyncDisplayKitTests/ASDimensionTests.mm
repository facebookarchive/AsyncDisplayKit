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

#import "ASDimension.h"


@interface ASDimensionTests : XCTestCase
@end

@implementation ASDimensionTests

- (void)testIntersectingOverlappingSizeRangesReturnsTheirIntersection
{
  //  range: |---------|
  //  other:      |----------|
  // result:      |----|

  ASSizeRange range = {{0,0}, {10,10}};
  ASSizeRange other = {{7,7}, {15,15}};
  ASSizeRange result = ASSizeRangeIntersect(range, other);
  ASSizeRange expected = {{7,7}, {10,10}};
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(result, expected), @"Expected %@ but got %@", NSStringFromASSizeRange(expected), NSStringFromASSizeRange(result));
}

- (void)testIntersectingSizeRangeWithRangeThatContainsItReturnsSameRange
{
  //  range:    |-----|
  //  other:  |---------|
  // result:    |-----|

  ASSizeRange range = {{2,2}, {8,8}};
  ASSizeRange other = {{0,0}, {10,10}};
  ASSizeRange result = ASSizeRangeIntersect(range, other);
  ASSizeRange expected = {{2,2}, {8,8}};
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(result, expected), @"Expected %@ but got %@", NSStringFromASSizeRange(expected), NSStringFromASSizeRange(result));
}

- (void)testIntersectingSizeRangeWithRangeContainedWithinItReturnsContainedRange
{
  //  range:  |---------|
  //  other:    |-----|
  // result:    |-----|

  ASSizeRange range = {{0,0}, {10,10}};
  ASSizeRange other = {{2,2}, {8,8}};
  ASSizeRange result = ASSizeRangeIntersect(range, other);
  ASSizeRange expected = {{2,2}, {8,8}};
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(result, expected), @"Expected %@ but got %@", NSStringFromASSizeRange(expected), NSStringFromASSizeRange(result));
}

- (void)testIntersectingSizeRangeWithNonOverlappingRangeToRightReturnsSinglePointNearestOtherRange
{
  //  range: |-----|
  //  other:          |---|
  // result:       *

  ASSizeRange range = {{0,0}, {5,5}};
  ASSizeRange other = {{10,10}, {15,15}};
  ASSizeRange result = ASSizeRangeIntersect(range, other);
  ASSizeRange expected = {{5,5}, {5,5}};
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(result, expected), @"Expected %@ but got %@", NSStringFromASSizeRange(expected), NSStringFromASSizeRange(result));
}

- (void)testIntersectingSizeRangeWithNonOverlappingRangeToLeftReturnsSinglePointNearestOtherRange
{
  //  range:          |---|
  //  other: |-----|
  // result:          *

  ASSizeRange range = {{10,10}, {15,15}};
  ASSizeRange other = {{0,0}, {5,5}};
  ASSizeRange result = ASSizeRangeIntersect(range, other);
  ASSizeRange expected = {{10,10}, {10,10}};
  XCTAssertTrue(ASSizeRangeEqualToSizeRange(result, expected), @"Expected %@ but got %@", NSStringFromASSizeRange(expected), NSStringFromASSizeRange(result));
}

@end
