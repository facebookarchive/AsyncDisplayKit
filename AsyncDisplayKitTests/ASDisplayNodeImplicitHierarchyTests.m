//
//  ASDisplayNodeImplicitHierarchyTests.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/1/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ASDisplayNode.h"
#import "ASDisplayNode+Beta.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASStaticLayoutSpec.h"

@interface ASSpecTestDisplayNode : ASDisplayNode

@property (copy, nonatomic) ASLayoutSpec * (^layoutSpecBlock)(ASSizeRange constrainedSize);

@end

@implementation ASSpecTestDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return self.layoutSpecBlock(constrainedSize);
}

@end

@interface ASDisplayNodeImplicitHierarchyTests : XCTestCase

@end

@implementation ASDisplayNodeImplicitHierarchyTests

- (void)setUp {
  [super setUp];
  [ASDisplayNode setUsesImplicitHierarchyManagement:YES];
}

- (void)tearDown {
  [ASDisplayNode setUsesImplicitHierarchyManagement:NO];
  [super tearDown];
}

- (void)testFeatureFlag
{
  XCTAssert([ASDisplayNode usesImplicitHierarchyManagement]);
}

- (void)testInitialNodeInsertion
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.layoutSpecBlock = ^(ASSizeRange constrainedSize){
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1, node2]];
  };
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  [node layout]; // Layout immediately
  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node2);
}

@end
