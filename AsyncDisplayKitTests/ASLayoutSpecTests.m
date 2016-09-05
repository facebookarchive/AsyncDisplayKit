//
//  ASLayoutSpecTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASStaticLayoutSpec.h>
#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import "ASLayoutableValidation.h"


@interface ASLayoutSpecTests : XCTestCase
@end


@implementation ASLayoutSpecTests

#if LAYOUT_VALIDATION
#pragma mark - Layout Validation

- (void)testStackLayoutableValidation
{
  id<ASLayoutable> layoutable = [[ASDisplayNode alloc] init];
  ASLayoutableValidationBlock block = ASLayoutableValidatorBlockRejectStackLayoutable();
  
  layoutable.layoutPosition = CGPointMake(100, 100);
  XCTAssertTrue(block(layoutable, nil), @"Should not reject ASStaticLayoutable properties");
  
  layoutable.flexGrow = YES;
  XCTAssertFalse(block(layoutable, nil), @"Should reject ASStackLayoutable properties");
}

- (void)testStaticLayoutableValidation
{
  id<ASLayoutable> layoutable = [[ASDisplayNode alloc] init];
  ASLayoutableValidationBlock block = ASLayoutableValidatorBlockRejectStaticLayoutable();
  
  layoutable.flexGrow = YES;
  XCTAssertTrue(block(layoutable, nil), @"Should not reject ASStackLayoutable properties");
  
  layoutable.layoutPosition = CGPointMake(100, 100);
  XCTAssertFalse(block(layoutable, nil), @"Should reject ASStaticLayoutable properties");
}

- (void)testSkipStackLayoutableValidation
{
  id<ASLayoutable> layoutable = [[ASDisplayNode alloc] init];
  layoutable.shouldValidate = NO;
  
  layoutable.layoutPosition = CGPointMake(100, 100);
  ASStackLayoutSpec *stackLayoutSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  XCTAssertNoThrow(stackLayoutSpec.children = @[layoutable]);
  
  layoutable.shouldValidate = YES;
  stackLayoutSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  stackLayoutSpec.shouldValidate = NO;
  XCTAssertNoThrow(stackLayoutSpec.children = @[layoutable]);
}

- (void)testSkipStaticLayoutableValidation
{
  id<ASLayoutable> layoutable = [[ASDisplayNode alloc] init];
  layoutable.shouldValidate = NO;
  
  layoutable.layoutPosition = CGPointMake(100, 100);
  ASStaticLayoutSpec *staticLayoutSpec = [[ASStaticLayoutSpec alloc] init];
  XCTAssertNoThrow(staticLayoutSpec.children = @[layoutable]);
  
  layoutable.shouldValidate = YES;
  staticLayoutSpec = [[ASStaticLayoutSpec alloc] init];
  staticLayoutSpec.shouldValidate = NO;
  XCTAssertNoThrow(staticLayoutSpec.children = @[layoutable]);
}
#endif

@end
