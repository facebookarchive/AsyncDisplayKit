//
//  ASWrapperSpecSnapshotTests.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//


#import "ASLayoutSpecSnapshotTestsHelper.h"
#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>

@interface ASWrapperSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASWrapperSpecSnapshotTests

- (void)testWrapperSpecWithOneElementShouldSizeToElement
{
  ASDisplayNode *child = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  
  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY));
  [self testWithChildren:@[child] sizeRange:sizeRange identifier:nil];
}

- (void)testWrapperSpecWithMultipleElementsShouldSizeToLargestElement
{
  ASDisplayNode *firstChild = ASDisplayNodeWithBackgroundColor([UIColor redColor], {50, 50});
  ASDisplayNode *secondChild = ASDisplayNodeWithBackgroundColor([UIColor greenColor], {100, 100});
  
  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY, INFINITY));
  [self testWithChildren:@[secondChild, firstChild] sizeRange:sizeRange identifier:nil];
}

- (void)testWithChildren:(NSArray *)children sizeRange:(ASSizeRange)sizeRange identifier:(NSString *)identifier
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor whiteColor]);

  NSMutableArray *subnodes = [NSMutableArray arrayWithArray:children];
  [subnodes insertObject:backgroundNode atIndex:0];

  ASLayoutSpec *layoutSpec =
  [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:
   [ASWrapperLayoutSpec
    wrapperWithLayoutElements:children]
   background:backgroundNode];
  
  [self testLayoutSpec:layoutSpec sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

@end
