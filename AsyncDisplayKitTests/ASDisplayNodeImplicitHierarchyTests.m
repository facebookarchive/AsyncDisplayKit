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
#import "ASStackLayoutSpec.h"

@interface ASSpecTestDisplayNode : ASDisplayNode

@property (copy, nonatomic) ASLayoutSpec * (^layoutSpecBlock)(ASSizeRange constrainedSize, NSNumber *layoutState);

/**
 Simple state identifier to allow control of current spec inside of the layoutSpecBlock
 */
@property (strong, nonatomic) NSNumber *layoutState;

@end

@implementation ASSpecTestDisplayNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    _layoutState = @1;
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return self.layoutSpecBlock(constrainedSize, _layoutState);
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
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  XCTAssert(node.usesImplicitHierarchyManagement);

  [ASDisplayNode setUsesImplicitHierarchyManagement:NO];
  XCTAssertFalse([ASDisplayNode usesImplicitHierarchyManagement]);
  XCTAssertFalse(node.usesImplicitHierarchyManagement);

  node.usesImplicitHierarchyManagement = YES;
  XCTAssert(node.usesImplicitHierarchyManagement);
}

- (void)testInitialNodeInsertionWithOrdering
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node4 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node5 = [[ASDisplayNode alloc] init];

  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.layoutSpecBlock = ^(ASSizeRange constrainedSize, NSNumber *layoutState) {
    ASStaticLayoutSpec *staticLayout = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node4]];
    
    ASStackLayoutSpec *stack1 = [[ASStackLayoutSpec alloc] init];
    [stack1 setChildren:@[node1, node2]];

    ASStackLayoutSpec *stack2 = [[ASStackLayoutSpec alloc] init];
    [stack2 setChildren:@[node3, staticLayout]];
    
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[stack1, stack2, node5]];
  };
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  XCTAssertEqual(node.subnodes[0], node5);
  XCTAssertEqual(node.subnodes[1], node1);
  XCTAssertEqual(node.subnodes[2], node2);
  XCTAssertEqual(node.subnodes[3], node3);
  XCTAssertEqual(node.subnodes[4], node4);
}

- (void)testCalculatedLayoutHierarchyTransitions
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.layoutSpecBlock = ^(ASSizeRange constrainedSize, NSNumber *layoutState){
    if ([layoutState isEqualToNumber:@1]) {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1, node2]];
    } else {
      ASStackLayoutSpec *stackLayout = [[ASStackLayoutSpec alloc] init];
      [stackLayout setChildren:@[node3, node2]];
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1, stackLayout]];
    }
  };
  
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node2);
  
  node.layoutState = @2;
  [node invalidateCalculatedLayout];
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];

  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node3);
  XCTAssertEqual(node.subnodes[2], node2);
}

@end
