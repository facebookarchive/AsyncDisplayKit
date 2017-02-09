//
//  ASLayoutSpecSnapshotTestsHelper.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>

@interface ASTestNode : ASDisplayNode
@property (strong, nonatomic, nullable) ASLayoutSpec *layoutSpecUnderTest;
@end

@implementation ASLayoutSpecSnapshotTestCase

- (void)setUp
{
  [super setUp];
  self.recordMode = NO;
}

- (void)testLayoutSpec:(ASLayoutSpec *)layoutSpec
             sizeRange:(ASSizeRange)sizeRange
              subnodes:(NSArray *)subnodes
            identifier:(NSString *)identifier
{
  ASTestNode *node = [[ASTestNode alloc] init];

  for (ASDisplayNode *subnode in subnodes) {
    [node addSubnode:subnode];
  }
  
  node.layoutSpecUnderTest = layoutSpec;
  
  ASDisplayNodeSizeToFitSizeRange(node, sizeRange);
  ASSnapshotVerifyNode(node, identifier);
}

@end

@implementation ASTestNode
- (instancetype)init
{
  if (self = [super init]) {
    self.layerBacked = YES;
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return _layoutSpecUnderTest;
}

@end
