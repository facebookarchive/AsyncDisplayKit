//
//  ASAbsoluteLayoutSpecSnapshotTests.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 18/10/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpecSnapshotTestsHelper.h"

#import <AsyncDisplayKit/ASAbsoluteLayoutSpec.h>
#import <AsyncDisplayKit/ASBackgroundLayoutSpec.h>

@interface ASAbsoluteLayoutSpecSnapshotTests : ASLayoutSpecSnapshotTestCase
@end

@implementation ASAbsoluteLayoutSpecSnapshotTests

- (void)testSizingBehaviour
{
  [self testWithSizeRange:ASSizeRangeMake(CGSizeMake(150, 200), CGSizeMake(INFINITY, INFINITY))
               identifier:@"underflowChildren"];
  [self testWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(50, 100))
               identifier:@"overflowChildren"];
  // Expect the spec to wrap its content because children sizes are between constrained size
  [self testWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeMake(INFINITY / 2, INFINITY / 2))
               identifier:@"wrappedChildren"];
}

- (void)testChildrenMeasuredWithAutoMaxSize
{
  ASDisplayNode *firstChild = ASDisplayNodeWithBackgroundColor([UIColor redColor], (CGSize){50, 50});
  firstChild.style.layoutPosition = CGPointMake(0, 0);
  
  ASDisplayNode *secondChild = ASDisplayNodeWithBackgroundColor([UIColor blueColor], (CGSize){100, 100});
  secondChild.style.layoutPosition = CGPointMake(10, 60);

  ASSizeRange sizeRange = ASSizeRangeMake(CGSizeMake(10, 10), CGSizeMake(110, 160));
  [self testWithChildren:@[firstChild, secondChild] sizeRange:sizeRange identifier:nil];
}

- (void)testWithSizeRange:(ASSizeRange)sizeRange identifier:(NSString *)identifier
{
  ASDisplayNode *firstChild = ASDisplayNodeWithBackgroundColor([UIColor redColor], (CGSize){50, 50});
  firstChild.style.layoutPosition = CGPointMake(0, 0);
  
  ASDisplayNode *secondChild = ASDisplayNodeWithBackgroundColor([UIColor blueColor], (CGSize){100, 100});
  secondChild.style.layoutPosition = CGPointMake(0, 50);
  
  [self testWithChildren:@[firstChild, secondChild] sizeRange:sizeRange identifier:identifier];
}

- (void)testWithChildren:(NSArray *)children sizeRange:(ASSizeRange)sizeRange identifier:(NSString *)identifier
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor whiteColor]);

  NSMutableArray *subnodes = [NSMutableArray arrayWithArray:children];
  [subnodes insertObject:backgroundNode atIndex:0];

  ASLayoutSpec *layoutSpec =
  [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:
   [ASAbsoluteLayoutSpec
    absoluteLayoutSpecWithChildren:children]
   background:backgroundNode];
  
  [self testLayoutSpec:layoutSpec sizeRange:sizeRange subnodes:subnodes identifier:identifier];
}

@end
