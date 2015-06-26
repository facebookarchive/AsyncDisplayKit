/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */


#import <OCMock/OCMock.h>

#import <AsyncDisplayKit/ASImageProtocols.h>
#import <AsyncDisplayKit/ASNetworkImageNode.h>

#import <libkern/OSAtomic.h>

#import <XCTest/XCTest.h>

@interface ASNetworkImageNodeTests : XCTestCase

@end

@implementation ASNetworkImageNodeTests

- (NSURL *)_testImageURL
{
  return [[NSBundle bundleForClass:[self class]] URLForResource:@"logo-square"
                                                  withExtension:@"png"
                                                   subdirectory:@"TestResources"];
}

- (UIImage *)_testImage
{
  return [[UIImage alloc] initWithContentsOfFile:[self _testImageURL].path];
}

- (UIImage *)_testPlaceholderImage
{
  return [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] URLForResource:@"placeholder"
                                                                                          withExtension:@"png"
                                                                                           subdirectory:@"TestResources"].path];
}

- (void)testNetworkImageNodeCanSetPlaceholderImage {
  ASNetworkImageNode *networkImage = [[ASNetworkImageNode alloc] init];
  
  NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"logo-square"
                                                                    ofType:@"png" inDirectory:@"TestResources"];

  UIImage *image = [UIImage imageWithContentsOfFile:path];
  networkImage.placeholderImage = image;
  
  XCTAssertEqualObjects(networkImage.placeholderImage, image, @"Placeholder was set");
}

- (void)testSettingURLSetsImageNodeBackToPlaceholder {
  ASNetworkImageNode *networkImage = [[ASNetworkImageNode alloc] init];
  
  networkImage.placeholderImage = [self _testPlaceholderImage];

  [networkImage setImage:[self _testImage]];
  
  networkImage.URL = [self _testImageURL];

  XCTAssertEqualObjects(UIImagePNGRepresentation(networkImage.image),
                        UIImagePNGRepresentation([self _testPlaceholderImage]),
                        @"Loaded image isn't the one we provided");
}

@end
