/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASLayoutNodeSnapshotTestsHelper.h"

#import "ASRatioLayoutNode.h"

static const ASSizeRange kFixedSize = {{0, 0}, {100, 100}};

@interface ASRatioLayoutNodeSnapshotTests : ASLayoutNodeSnapshotTestCase
@end

@implementation ASRatioLayoutNodeSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testRatioLayoutNodeWithRatio:(CGFloat)ratio childNodeSize:(CGSize)childNodeSize identifier:(NSString *)identifier
{
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
  subnode.staticSize = childNodeSize;
  
  ASLayoutNode *layoutNode = [ASRatioLayoutNode
                              newWithRatio:ratio
                              node:[ASCompositeNode newWithDisplayNode:subnode]];
  
  [self testLayoutNode:layoutNode sizeRange:kFixedSize subnodes:@[subnode] identifier:identifier];
}

- (void)testRatioLayout
{
  [self testRatioLayoutNodeWithRatio:0.5 childNodeSize:CGSizeMake(100, 100) identifier:@"HalfRatio"];
  [self testRatioLayoutNodeWithRatio:2.0 childNodeSize:CGSizeMake(100, 100) identifier:@"DoubleRatio"];
  [self testRatioLayoutNodeWithRatio:7.0 childNodeSize:CGSizeMake(100, 100) identifier:@"SevenTimesRatio"];
  [self testRatioLayoutNodeWithRatio:10.0 childNodeSize:CGSizeMake(20, 200) identifier:@"TenTimesRatioWithItemTooBig"];
}

@end
