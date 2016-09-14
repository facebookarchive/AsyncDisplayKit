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
  [imageNode measure:CGSizeMake(100, 100)];

  ASSnapshotVerifyNode(imageNode, nil);
}

- (void)testForcedScaling
{
  ASImageNode *imageNode = [[ASImageNode alloc] init];
  
  imageNode.image = [self testImage];
  imageNode.forcedSize = CGSizeMake(100, 100);
  
  // Snapshot testing requires that node is formally laid out.
  imageNode.preferredFrameSize = CGSizeMake(100, 100);
  [imageNode measure:CGSizeMake(100, 100)];

  ASSnapshotVerifyNode(imageNode, @"first");
  
  imageNode.preferredFrameSize = CGSizeMake(200, 200);
  [imageNode measure:CGSizeMake(200, 200)];
  
  ASSnapshotVerifyNode(imageNode, @"second");
  
  XCTAssert(CGImageGetWidth((CGImageRef)imageNode.contents) == 100 * imageNode.contentsScale && CGImageGetHeight((CGImageRef)imageNode.contents) == 100 * imageNode.contentsScale, @"contents should be 100 x 100 by contents scale.");
}

@end
