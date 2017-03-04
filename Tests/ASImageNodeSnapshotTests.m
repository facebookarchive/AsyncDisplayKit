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

- (void)setUp
{
  [super setUp];
  
  self.recordMode = NO;
}

- (UIImage *)testImage
{
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"logo-square"
                                                                    ofType:@"png"
                                                               inDirectory:@"TestResources"];
  return [UIImage imageWithContentsOfFile:path];
}

- (void)testRenderLogoSquare
{
  // trivial test case to ensure ASSnapshotTestCase works
  ASImageNode *imageNode = [[ASImageNode alloc] init];
  imageNode.image = [self testImage];
  ASDisplayNodeSizeToFitSize(imageNode, CGSizeMake(100, 100));

  ASSnapshotVerifyNode(imageNode, nil);
}

- (void)testForcedScaling
{
  CGSize forcedImageSize = CGSizeMake(100, 100);
  
  ASImageNode *imageNode = [[ASImageNode alloc] init];
  imageNode.forcedSize = forcedImageSize;
  imageNode.image = [self testImage];
  
  // Snapshot testing requires that node is formally laid out.
  imageNode.style.width = ASDimensionMake(forcedImageSize.width);
  imageNode.style.height = ASDimensionMake(forcedImageSize.height);
  ASDisplayNodeSizeToFitSize(imageNode, forcedImageSize);
  ASSnapshotVerifyNode(imageNode, @"first");
  
  imageNode.style.width = ASDimensionMake(200);
  imageNode.style.height = ASDimensionMake(200);
  ASDisplayNodeSizeToFitSize(imageNode, CGSizeMake(200, 200));
  ASSnapshotVerifyNode(imageNode, @"second");
  
  XCTAssert(CGImageGetWidth((CGImageRef)imageNode.contents) == forcedImageSize.width * imageNode.contentsScale &&
            CGImageGetHeight((CGImageRef)imageNode.contents) == forcedImageSize.height * imageNode.contentsScale,
            @"Contents should be 100 x 100 by contents scale.");
}

- (void)testTintColorBlock
{
  UIImage *test = [self testImage];
  UIImage *tinted = ASImageNodeTintColorModificationBlock([UIColor redColor])(test);
  ASImageNode *node = [[ASImageNode alloc] init];
  node.image = tinted;
  ASDisplayNodeSizeToFitSize(node, test.size);
  
  ASSnapshotVerifyNode(node, nil);
}

- (void)testRoundedCornerBlock
{
  UIGraphicsBeginImageContext(CGSizeMake(100, 100));
  [[UIColor blueColor] setFill];
  UIRectFill(CGRectMake(0, 0, 100, 100));
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  UIImage *rounded = ASImageNodeRoundBorderModificationBlock(2, [UIColor redColor])(result);
  ASImageNode *node = [[ASImageNode alloc] init];
  node.image = rounded;
  ASDisplayNodeSizeToFitSize(node, rounded.size);
  
  ASSnapshotVerifyNode(node, nil);
}

@end
