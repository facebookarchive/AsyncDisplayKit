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
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor]);
  
  ASLayoutNode *layoutNode =
  [ASBackgroundLayoutNode
   newWithNode:
   [ASCenterLayoutNode
    newWithCenteringOptions:options
    sizingOptions:sizingOptions
    child:[ASCompositeNode newWithSize:ASLayoutNodeSizeMake(70.0, 100.0) displayNode:foregroundNode]
    size:{}]
   background:[ASCompositeNode newWithDisplayNode:backgroundNode]];

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
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  
  ASCenterLayoutNode *layoutNode =
  [ASCenterLayoutNode
   newWithCenteringOptions:ASCenterLayoutNodeCenteringNone
   sizingOptions:{}
   child:
   [ASBackgroundLayoutNode
    newWithNode:
    [ASStackLayoutNode
     newWithSize:{}
     style:{}
     children:@[[ASStackLayoutNodeChild newWithInitializer:^(ASMutableStackLayoutNodeChild *mutableChild) {
      mutableChild.node = [ASCompositeNode newWithSize:ASLayoutNodeSizeMake(10, 10) displayNode:foregroundNode];
      mutableChild.flexGrow = YES;
     }]]]
    background: [ASCompositeNode newWithDisplayNode:backgroundNode]]
   size:{}];

  [self testLayoutNode:layoutNode sizeRange:kSize subnodes:@[backgroundNode, foregroundNode] identifier:nil];
}

@end
