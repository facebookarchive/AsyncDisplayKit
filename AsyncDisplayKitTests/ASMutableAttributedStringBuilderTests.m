/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASMutableAttributedStringBuilder.h"

@interface ASMutableAttributedStringBuilderTests : XCTestCase

@end

@implementation ASMutableAttributedStringBuilderTests

- (NSString *)_string
{
  return @"Normcore PBR hella, viral slow-carb mustache chillwave church-key cornhole messenger bag swag vinyl biodiesel ethnic. Fashion axe messenger bag raw denim street art. Flannel Wes Anderson normcore church-key 8-bit. Master cleanse four loko try-hard Carles stumptown ennui, twee literally wayfarers kitsch tofu PBR. Cliche organic post-ironic Wes Anderson kale chips fashion axe. Narwhal Blue Bottle sustainable, Odd Future Godard sriracha banjo disrupt Marfa irony pug Wes Anderson YOLO yr church-key. Mlkshk Intelligentsia semiotics quinoa, butcher meggings wolf Bushwick keffiyeh ethnic pour-over Pinterest letterpress.";
}

- (ASMutableAttributedStringBuilder *)_builder
{
  return [[ASMutableAttributedStringBuilder alloc] initWithString:[self _string]];
}

- (NSRange)_randomizedRangeForStringBuilder:(ASMutableAttributedStringBuilder *)builder
{
  NSUInteger loc = arc4random() % (builder.length - 1);
  NSUInteger len = arc4random() % (builder.length - loc);
  len = ((len > 0) ? len : 1);
  return NSMakeRange(loc, len);
}

- (void)testSimpleAttributions
{
  // Add a attributes, and verify that they get set on the correct locations.
  for (int i = 0; i < 100; i++) {
    ASMutableAttributedStringBuilder *builder = [self _builder];
    NSRange range = [self _randomizedRangeForStringBuilder:builder];
    NSString *keyValue = [NSString stringWithFormat:@"%d", i];
    [builder addAttribute:keyValue value:keyValue range:range];
    NSAttributedString *attrStr = [builder composedAttributedString];
    XCTAssertEqual(builder.length, attrStr.length, @"out string should have same length as builder");
    __block BOOL found = NO;
    [attrStr enumerateAttributesInRange:NSMakeRange(0, attrStr.length) options:0 usingBlock:^(NSDictionary *attrs, NSRange r, BOOL *stop) {
      if ([attrs[keyValue] isEqualToString:keyValue]) {
        XCTAssertTrue(NSEqualRanges(range, r), @"enumerated range %@ should be equal to the set range %@", NSStringFromRange(r), NSStringFromRange(range));
        found = YES;
      }
    }];
    XCTAssertTrue(found, @"enumeration should have found the attribute we set");
  }
}

- (void)testSetOverAdd
{
  ASMutableAttributedStringBuilder *builder = [self _builder];
  NSRange addRange = NSMakeRange(0, builder.length);
  NSRange setRange = NSMakeRange(0, 1);
  [builder addAttribute:@"attr" value:@"val1" range:addRange];
  [builder setAttributes:@{@"attr" : @"val2"} range:setRange];
  NSAttributedString *attrStr = [builder composedAttributedString];
  NSRange setRangeOut;
  NSString *setAttr = [attrStr attribute:@"attr" atIndex:0 effectiveRange:&setRangeOut];
  XCTAssertTrue(NSEqualRanges(setRange, setRangeOut), @"The out set range should equal the range we used originally");
  XCTAssertEqualObjects(setAttr, @"val2", @"the set value should be val2");

  NSRange addRangeOut;
  NSString *addAttr = [attrStr attribute:@"attr" atIndex:2 effectiveRange:&addRangeOut];
  XCTAssertTrue(NSEqualRanges(NSMakeRange(1, builder.length - 1), addRangeOut), @"the add range should only cover beyond the set range");
  XCTAssertEqualObjects(addAttr, @"val1", @"the added attribute should be present at index 2");
}

@end
