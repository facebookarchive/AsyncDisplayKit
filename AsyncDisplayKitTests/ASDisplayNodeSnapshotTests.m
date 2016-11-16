//
//  ASDisplayNodeSnapshotTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/16/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASSnapshotTestCase.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASDisplayNodeSnapshotTests : ASSnapshotTestCase

@end

@implementation ASDisplayNodeSnapshotTests

- (void)testBasicHierarchySnapshotTesting
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.backgroundColor = [UIColor blueColor];
  
  ASTextNode *subnode = [[ASTextNode alloc] init];
  subnode.backgroundColor = [UIColor whiteColor];
  
  subnode.attributedText = [[NSAttributedString alloc] initWithString:@"Hello"];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(5, 5, 5, 5) child:subnode];
  };

  ASDisplayNodeSizeToFitSizeRange(node, ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY)));
  ASSnapshotVerifyNode(node, nil);
}

@end
