//
//  ASImageNodeSnapshotTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASSnapshotTestCase.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASImageNodeSnapshotTests : ASSnapshotTestCase
@end

@implementation ASImageNodeSnapshotTests

- (UIImage *)testImage
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"logo-square"
                                                                    ofType:@"png" inDirectory:@"TestResources"];
  return [UIImage imageWithContentsOfFile:path];
}

- (void)testRenderLogoSquare
{
  // trivial test case to ensure ASSnapshotTestCase works
  ASImageNode *imageNode = [[ASImageNode alloc] init];
  imageNode.image = [self testImage];
  imageNode.frame = CGRectMake(0, 0, 100, 100);

  ASSnapshotVerifyNode(imageNode, nil);
}

- (void)testForcedScaling
{
  ASDisplayNode *containerNode = [[ASDisplayNode alloc] init];
  ASImageNode *imageNode = [[ASImageNode alloc] init];
  [containerNode addSubnode:imageNode];
  
  imageNode.image = [self testImage];
  containerNode.frame = CGRectMake(0, 0, 100, 100);
  imageNode.frame = containerNode.bounds;
  imageNode.forcedSize = CGSizeMake(100, 100);
  
  ASSnapshotVerifyNode(containerNode, @"first");
  
  containerNode.frame = CGRectMake(0, 0, 200, 200);
  imageNode.frame = containerNode.bounds;
  
  ASSnapshotVerifyNode(containerNode, @"second");
}

@end
