/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import "ASRatioLayoutSpec.h"

static const ASSizeRange kFixedSize = {{0, 0}, {100, 100}};

@interface ASRatioLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASRatioLayoutSpecSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testRatioLayoutSpecWithRatio:(CGFloat)ratio childSize:(CGSize)childSize identifier:(NSString *)identifier
{
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
  subnode.staticSize = childSize;
  
  ASLayoutSpec *layoutSpec = [ASRatioLayoutSpec newWithRatio:ratio child:subnode];
  
  [self testLayoutSpec:layoutSpec sizeRange:kFixedSize subnodes:@[subnode] identifier:identifier];
}

- (void)testRatioLayout
{
  [self testRatioLayoutSpecWithRatio:0.5 childSize:CGSizeMake(100, 100) identifier:@"HalfRatio"];
  [self testRatioLayoutSpecWithRatio:2.0 childSize:CGSizeMake(100, 100) identifier:@"DoubleRatio"];
  [self testRatioLayoutSpecWithRatio:7.0 childSize:CGSizeMake(100, 100) identifier:@"SevenTimesRatio"];
  [self testRatioLayoutSpecWithRatio:10.0 childSize:CGSizeMake(20, 200) identifier:@"TenTimesRatioWithItemTooBig"];
}

@end
