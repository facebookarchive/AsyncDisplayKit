//
//  ASLayoutElementStyleTests.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASLayoutElement.h"

#pragma mark - ASLayoutElementStyleTestsDelegate

@interface ASLayoutElementStyleTestsDelegate : NSObject<ASLayoutElementStyleDelegate>
@property (copy, nonatomic) NSString *propertyNameChanged;
@end

@implementation ASLayoutElementStyleTestsDelegate

- (void)style:(id)style propertyDidChange:(NSString *)propertyName
{
  self.propertyNameChanged = propertyName;
}

@end

#pragma mark - ASLayoutElementStyleTests

@interface ASLayoutElementStyleTests : XCTestCase

@end

@implementation ASLayoutElementStyleTests

- (void)testSettingSizeProperties
{
  ASLayoutElementStyle *style = [ASLayoutElementStyle new];
  style.width = ASDimensionMake(100);
  style.height = ASDimensionMake(100);
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.height, ASDimensionMake(100)));
}

- (void)testSettingSizeViaHelper
{
  ASLayoutElementStyle *style = [ASLayoutElementStyle new];
  [style setSizeWithCGSize:CGSizeMake(100, 100)];
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.height, ASDimensionMake(100)));
}

- (void)testSettingExactSize
{
  ASLayoutElementStyle *style = [ASLayoutElementStyle new];
  [style setExactSizeWithCGSize:CGSizeMake(100, 100)];
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.minWidth, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.minHeight, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.maxWidth, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.maxHeight, ASDimensionMake(100)));
}
  
- (void)testSettingPropertiesWillCallDelegate
{
  ASLayoutElementStyleTestsDelegate *delegate = [ASLayoutElementStyleTestsDelegate new];
  ASLayoutElementStyle *style = [[ASLayoutElementStyle alloc] initWithDelegate:delegate];
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionAuto));
  style.width = ASDimensionMake(100);
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue([delegate.propertyNameChanged isEqualToString:ASLayoutElementStyleWidthProperty]);
}

@end
