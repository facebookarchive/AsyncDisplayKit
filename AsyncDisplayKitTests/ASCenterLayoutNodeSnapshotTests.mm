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

#import "ASBackgroundLayoutNode.h"
#import "ASCenterLayoutNode.h"
#import "ASStackLayoutNode.h"

static const ASSizeRange kSize = {{100, 120}, {320, 160}};

@interface ASCenterLayoutNodeSnapshotTests : ASLayoutNodeSnapshotTestCase
@end

@implementation ASCenterLayoutNodeSnapshotTests

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testWithOptions
{
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringNone sizingOptions:{}];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringXY sizingOptions:{}];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringX sizingOptions:{}];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringY sizingOptions:{}];
}

- (void)testWithSizingOptions
{
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringNone sizingOptions:ASCenterLayoutNodeSizingOptionDefault];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringNone sizingOptions:ASCenterLayoutNodeSizingOptionMinimumX];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringNone sizingOptions:ASCenterLayoutNodeSizingOptionMinimumY];
  [self testWithCenteringOptions:ASCenterLayoutNodeCenteringNone sizingOptions:ASCenterLayoutNodeSizingOptionMinimumXY];
}

- (void)testWithCenteringOptions:(ASCenterLayoutNodeCenteringOptions)options
                   sizingOptions:(ASCenterLayoutNodeSizingOptions)sizingOptions
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
  foregroundNode.staticSize = {70, 100};

  
  ASLayoutNode *layoutNode =
  [ASBackgroundLayoutNode
   newWithChild:
   [ASCenterLayoutNode
    newWithCenteringOptions:options
    sizingOptions:sizingOptions
    child:foregroundNode]
   background:backgroundNode];

  [self testLayoutNode:layoutNode
             sizeRange:kSize
              subnodes:@[backgroundNode, foregroundNode]
            identifier:suffixForCenteringOptions(options, sizingOptions)];
}

static NSString *suffixForCenteringOptions(ASCenterLayoutNodeCenteringOptions centeringOptions,
                                           ASCenterLayoutNodeSizingOptions sizingOptinos)
{
  NSMutableString *suffix = [NSMutableString string];

  if ((centeringOptions & ASCenterLayoutNodeCenteringX) != 0) {
    [suffix appendString:@"CenteringX"];
  }

  if ((centeringOptions & ASCenterLayoutNodeCenteringY) != 0) {
    [suffix appendString:@"CenteringY"];
  }

  if ((sizingOptinos & ASCenterLayoutNodeSizingOptionMinimumX) != 0) {
    [suffix appendString:@"SizingMinimumX"];
  }

  if ((sizingOptinos & ASCenterLayoutNodeSizingOptionMinimumY) != 0) {
    [suffix appendString:@"SizingMinimumY"];
  }

  return suffix;
}

- (void)testMinimumSizeRangeIsGivenToChildWhenNotCentering
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  foregroundNode.staticSize = {10, 10};
  foregroundNode.flexGrow = YES;
  
  ASCenterLayoutNode *layoutNode =
  [ASCenterLayoutNode
   newWithCenteringOptions:ASCenterLayoutNodeCenteringNone
   sizingOptions:{}
   child:
   [ASBackgroundLayoutNode
    newWithChild:[ASStackLayoutNode newWithStyle:{} children:@[foregroundNode]]
    background:backgroundNode]];

  [self testLayoutNode:layoutNode sizeRange:kSize subnodes:@[backgroundNode, foregroundNode] identifier:nil];
}

@end
