//
//  ASLayoutableStyleTests.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASLayoutable.h"

#pragma mark - ASLayoutableStyleTestsDelegate

@interface ASLayoutableStyleTestsDelegate : NSObject<ASLayoutableStyleDelegate>
@property (copy, nonatomic) NSString *propertyNameChanged;
@end

@implementation ASLayoutableStyleTestsDelegate

- (void)style:(id)style propertyDidChange:(NSString *)propertyName
{
  self.propertyNameChanged = propertyName;
}

@end

#pragma mark - ASLayoutableStyleTests

@interface ASLayoutableStyleTests : XCTestCase

@end

@implementation ASLayoutableStyleTests

- (void)testSettingSizeProperties
{
  ASLayoutableStyle *style = [ASLayoutableStyle new];
  style.width = ASDimensionMake(100);
  style.height = ASDimensionMake(100);
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.height, ASDimensionMake(100)));
}

- (void)testSettingSizeViaHelper
{
  ASLayoutableStyle *style = [ASLayoutableStyle new];
  [style setSizeWithCGSize:CGSizeMake(100, 100)];
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.height, ASDimensionMake(100)));
}

- (void)testSettingExactSize
{
  ASLayoutableStyle *style = [ASLayoutableStyle new];
  [style setExactSizeWithCGSize:CGSizeMake(100, 100)];
  
  XCTAssertTrue(ASDimensionEqualToDimension(style.minWidth, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.minHeight, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.maxWidth, ASDimensionMake(100)));
  XCTAssertTrue(ASDimensionEqualToDimension(style.maxHeight, ASDimensionMake(100)));
}
  
- (void)testSettingPropertiesWillCallDelegate
{
  ASLayoutableStyleTestsDelegate *delegate = [ASLayoutableStyleTestsDelegate new];
  ASLayoutableStyle *style = [[ASLayoutableStyle alloc] initWithDelegate:delegate];
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionAuto));
  style.width = ASDimensionMake(100);
  XCTAssertTrue(ASDimensionEqualToDimension(style.width, ASDimensionMake(100)));
  XCTAssertTrue([delegate.propertyNameChanged isEqualToString:ASLayoutableStyleWidthProperty]);
}

@end
