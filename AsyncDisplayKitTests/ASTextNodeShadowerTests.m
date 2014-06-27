/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASTextNodeShadower.h"

@interface ASTextNodeShadowerTests : XCTestCase

@property (nonatomic, readwrite, strong) ASTextNodeShadower *shadower;

@end

@implementation ASTextNodeShadowerTests

- (void)testInstantiation
{
  CGSize shadowOffset = CGSizeMake(3, 5);
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 0.3;
  CGFloat shadowRadius = 4.2;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                            shadowColor:shadowColor
                                                          shadowOpacity:shadowOpacity
                                                           shadowRadius:shadowRadius];
  XCTAssertNotNil(_shadower, @"Couldn't instantiate shadow drawer");
  XCTAssertTrue(CGSizeEqualToSize(_shadower.shadowOffset, shadowOffset), @"Failed to set shadowOffset (%@) to %@", NSStringFromCGSize(_shadower.shadowOffset), NSStringFromCGSize(shadowOffset));
  XCTAssertTrue(_shadower.shadowColor == shadowColor, @"Failed to set shadowColor (%@) to %@", _shadower.shadowColor, shadowColor);
  XCTAssertTrue(_shadower.shadowOpacity == shadowOpacity, @"Failed to set shadowOpacity (%f) to %f", _shadower.shadowOpacity, shadowOpacity);
  XCTAssertTrue(_shadower.shadowRadius == shadowRadius, @"Failed to set shadowRadius (%f) to %f", _shadower.shadowRadius, shadowRadius);
  CGColorRelease(shadowColor);
}

- (void)testNoShadowIfNoRadiusAndNoOffset
{
  CGSize shadowOffset = CGSizeZero;
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 0.3;
  CGFloat shadowRadius = 0;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                            shadowColor:shadowColor
                                                          shadowOpacity:shadowOpacity
                                                           shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, UIEdgeInsetsZero), @"There should be no shadow padding if shadow radius is zero");
  CGColorRelease(shadowColor);
}

- (void)testShadowIfOffsetButNoRadius
{
  CGSize shadowOffset = CGSizeMake(3, 5);
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 0.3;
  CGFloat shadowRadius = 0;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                    shadowColor:shadowColor
                                                  shadowOpacity:shadowOpacity
                                                   shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  UIEdgeInsets expectedInsets = UIEdgeInsetsMake(0, 0, -5, -3);
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, expectedInsets), @"Expected insets %@, encountered insets %@", NSStringFromUIEdgeInsets(expectedInsets), NSStringFromUIEdgeInsets(shadowPadding));
  CGColorRelease(shadowColor);
}

- (void)testNoShadowIfNoOpacity
{
  CGSize shadowOffset = CGSizeMake(3, 5);
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 0;
  CGFloat shadowRadius = 4;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                            shadowColor:shadowColor
                                                          shadowOpacity:shadowOpacity
                                                           shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, UIEdgeInsetsZero), @"There should be no shadow padding if shadow opacity is zero");
  CGColorRelease(shadowColor);
}

- (void)testShadowPaddingForRadiusOf4
{
  CGSize shadowOffset = CGSizeZero;
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 1;
  CGFloat shadowRadius = 4;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                            shadowColor:shadowColor
                                                          shadowOpacity:shadowOpacity
                                                           shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  UIEdgeInsets expectedInsets = UIEdgeInsetsMake(-shadowRadius, -shadowRadius, -shadowRadius, -shadowRadius);
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, expectedInsets), @"Unexpected edge insets %@ for radius of %f ", NSStringFromUIEdgeInsets(shadowPadding), shadowRadius);
  CGColorRelease(shadowColor);
}

- (void)testShadowPaddingForRadiusOf4OffsetOf11
{
  CGSize shadowOffset = CGSizeMake(1, 1);
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 1;
  CGFloat shadowRadius = 4;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                            shadowColor:shadowColor
                                                          shadowOpacity:shadowOpacity
                                                           shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  UIEdgeInsets expectedInsets = UIEdgeInsetsMake(-shadowRadius + shadowOffset.height, // Top: -3
                                                 -shadowRadius + shadowOffset.width,  // Left: -3
                                                 -shadowRadius - shadowOffset.height, // Bottom: -5
                                                 -shadowRadius - shadowOffset.width);  // Right: -5
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, expectedInsets), @"Unexpected edge insets %@ for radius of %f ", NSStringFromUIEdgeInsets(shadowPadding), shadowRadius);
  CGColorRelease(shadowColor);
}

- (void)testShadowPaddingForRadiusOf4OffsetOfNegative11
{
  CGSize shadowOffset = CGSizeMake(-1, -1);
  CGColorRef shadowColor = CGColorRetain([UIColor blackColor].CGColor);
  CGFloat shadowOpacity = 1;
  CGFloat shadowRadius = 4;
  _shadower =  [[ASTextNodeShadower alloc] initWithShadowOffset:shadowOffset
                                                    shadowColor:shadowColor
                                                  shadowOpacity:shadowOpacity
                                                   shadowRadius:shadowRadius];
  UIEdgeInsets shadowPadding = [_shadower shadowPadding];
  UIEdgeInsets expectedInsets = UIEdgeInsetsMake(-shadowRadius + shadowOffset.height, // Top: -3
                                                 -shadowRadius + shadowOffset.width,  // Left: -5
                                                 -shadowRadius - shadowOffset.height, // Bottom: -5
                                                 -shadowRadius - shadowOffset.width);  // Right: -3
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(shadowPadding, expectedInsets), @"Unexpected edge insets %@ for radius of %f ", NSStringFromUIEdgeInsets(shadowPadding), shadowRadius);
  CGColorRelease(shadowColor);
}

- (void)testASDNEdgeInsetsInvert
{
  UIEdgeInsets insets = UIEdgeInsetsMake(-5, -7, -3, -2);
  UIEdgeInsets invertedInsets = ASDNEdgeInsetsInvert(insets);
  UIEdgeInsets expectedInsets = UIEdgeInsetsMake(5, 7, 3, 2);
  XCTAssertTrue(UIEdgeInsetsEqualToEdgeInsets(invertedInsets, expectedInsets), @"Expected %@, actual result %@", NSStringFromUIEdgeInsets(expectedInsets), NSStringFromUIEdgeInsets(invertedInsets));
}

- (void)testASDNEdgeInsetsInvertDoubleNegation
{
  CGRect originalRect = CGRectMake(31, 32, 33, 34);
  UIEdgeInsets insets = UIEdgeInsetsMake(-5, -7, -3, -2);
  CGRect insettedRect = UIEdgeInsetsInsetRect(originalRect, insets);
  CGRect outsettedInsettedRect = UIEdgeInsetsInsetRect(insettedRect, ASDNEdgeInsetsInvert(insets));
  XCTAssertTrue(CGRectEqualToRect(originalRect, outsettedInsettedRect), @"Insetting a CGRect, and then outsetting it (insetting with the negated edge insets) should return the original CGRect");
}

@end
