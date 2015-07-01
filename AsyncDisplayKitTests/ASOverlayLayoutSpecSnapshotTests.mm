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

#import "ASOverlayLayoutSpec.h"
#import "ASCenterLayoutSpec.h"

static const ASSizeRange kSize = {{320, 320}, {320, 320}};

@interface ASOverlayLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASOverlayLayoutSpecSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testOverlay
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor blackColor]);
  foregroundNode.staticSize = {20, 20};
  
  ASLayoutSpec *layoutSpec =
  [ASOverlayLayoutSpec
   newWithChild:backgroundNode
   overlay:
   [ASCenterLayoutSpec
    newWithCenteringOptions:ASCenterLayoutSpecCenteringXY
    sizingOptions:{}
    child:foregroundNode]];
  
  [self testLayoutSpec:layoutSpec sizeRange:kSize subnodes:@[backgroundNode, foregroundNode] identifier: nil];
}

@end
