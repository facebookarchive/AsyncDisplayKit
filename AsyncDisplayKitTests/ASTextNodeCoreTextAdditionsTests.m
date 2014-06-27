/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <CoreText/CoreText.h>

#import <XCTest/XCTest.h>

#import "ASTextNodeCoreTextAdditions.h"

@interface ASTextNodeCoreTextAdditionsTests : XCTestCase

@end

@implementation ASTextNodeCoreTextAdditionsTests

- (void)testAttributeCleansing
{
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0]}];
  CFRange cfRange = CFRangeMake(0, testString.length);
  CGColorRef blueColor = CGColorRetain([UIColor blueColor].CGColor);
  CFAttributedStringSetAttribute((CFMutableAttributedStringRef)testString,
                                 cfRange,
                                 kCTForegroundColorAttributeName,
                                 blueColor);
  NSAttributedString *expectedCleansedString = [[NSAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0],
                                                                                                               NSForegroundColorAttributeName:[UIColor colorWithCGColor:blueColor]}];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([expectedCleansedString isEqualToAttributedString:actualCleansedString], @"Expected the %@ core text attribute to be cleansed from the string %@", kCTForegroundColorFromContextAttributeName, actualCleansedString);
  CGColorRelease(blueColor);
}

- (void)testNoAttributeCleansing
{
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0],
                                                                                                                 NSForegroundColorAttributeName : [UIColor blueColor]}];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([testString isEqualToAttributedString:actualCleansedString], @"Expected the output string %@ to be the same as the input %@ if there are no core text attributes", actualCleansedString, testString);
}


@end
