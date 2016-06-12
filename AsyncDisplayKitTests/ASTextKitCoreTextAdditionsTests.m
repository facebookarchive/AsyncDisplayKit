//
//  ASTextKitCoreTextAdditionsTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <CoreText/CoreText.h>

#import <XCTest/XCTest.h>

#import "ASTextKitCoreTextAdditions.h"

BOOL floatsCloseEnough(CGFloat float1, CGFloat float2) {
  CGFloat epsilon = 0.00001;
  return (fabs(float1 - float2) < epsilon);
}

@interface ASTextKitCoreTextAdditionsTests : XCTestCase

@end

@implementation ASTextKitCoreTextAdditionsTests

- (void)testAttributeCleansing
{
  UIFont *font = [UIFont systemFontOfSize:12.0];
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:font}];
  CFRange cfRange = CFRangeMake(0, testString.length);
  CGColorRef blueColor = CGColorRetain([UIColor blueColor].CGColor);
  CFAttributedStringSetAttribute((CFMutableAttributedStringRef)testString,
                                 cfRange,
                                 kCTForegroundColorAttributeName,
                                 blueColor);
  UIColor *color = [UIColor colorWithCGColor:blueColor];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([[actualCleansedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL] isEqual:color], @"Expected the %@ core text attribute to be cleansed from the string %@\n Should match %@", kCTForegroundColorFromContextAttributeName, actualCleansedString, color);
  CGColorRelease(blueColor);
}

- (void)testNoAttributeCleansing
{
  NSMutableAttributedString *testString = [[NSMutableAttributedString alloc] initWithString:@"Test" attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12.0],
                                                                                                                 NSForegroundColorAttributeName : [UIColor blueColor]}];

  NSAttributedString *actualCleansedString = ASCleanseAttributedStringOfCoreTextAttributes(testString);
  XCTAssertTrue([testString isEqualToAttributedString:actualCleansedString], @"Expected the output string %@ to be the same as the input %@ if there are no core text attributes", actualCleansedString, testString);
}

- (void)testNSParagraphStyleNoCleansing
{
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.lineSpacing = 10.0;

  //NSUnderlineStyleAttributeName flags the unsupported CT attribute check
  NSDictionary *attributes = @{NSParagraphStyleAttributeName:paragraphStyle,
                               NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)};

  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:@"Test" attributes:attributes];
  NSAttributedString *cleansedString = ASCleanseAttributedStringOfCoreTextAttributes(attributedString);

  NSParagraphStyle *cleansedParagraphStyle = [cleansedString attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];

  XCTAssertTrue(floatsCloseEnough(cleansedParagraphStyle.lineSpacing, paragraphStyle.lineSpacing), @"Expected the output line spacing: %f to be equal to the input line spacing: %f", cleansedParagraphStyle.lineSpacing, paragraphStyle.lineSpacing);
}

@end
