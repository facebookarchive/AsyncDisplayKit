//
//  ASPhotosImageRequestTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/25/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASPhotosImageRequest.h"

static NSString *const kTestAssetID = @"testAssetID";

@interface ASPhotosImageRequestTests : XCTestCase

@end

@implementation ASPhotosImageRequestTests

#pragma mark Example Data

+ (ASPhotosImageRequest *)exampleImageRequest
{
  ASPhotosImageRequest *req = [[ASPhotosImageRequest alloc] initWithAssetIdentifier:kTestAssetID];
  req.options.networkAccessAllowed = YES;
  req.options.normalizedCropRect = CGRectMake(0.2, 0.1, 0.6, 0.8);
  req.targetSize = CGSizeMake(1024, 1536);
  req.contentMode = PHImageContentModeAspectFill;
  req.options.version = PHImageRequestOptionsVersionOriginal;
  req.options.resizeMode = PHImageRequestOptionsResizeModeFast;
  return req;
}

+ (NSURL *)urlForExampleImageRequest
{
  NSString *str = [NSString stringWithFormat:@"ph://%@?width=1024&height=1536&version=2&contentmode=1&network=1&resizemode=1&crop_x=0.2&crop_y=0.1&crop_w=0.6&crop_h=0.8", kTestAssetID];
  return [NSURL URLWithString:str];
}

#pragma mark Test cases

- (void)testThatConvertingToURLWorks
{
  XCTAssertEqualObjects([self.class exampleImageRequest].url, [self.class urlForExampleImageRequest]);
}

- (void)testThatParsingFromURLWorks
{
  XCTAssertEqualObjects([self.class urlForExampleImageRequest].asyncdisplaykit_photosRequest, [self.class exampleImageRequest]);
}

- (void)testThatCopyingWorks
{
  ASPhotosImageRequest *example = [self.class exampleImageRequest];
  ASPhotosImageRequest *copy = [[self.class exampleImageRequest] copy];
  XCTAssertEqualObjects(example, copy);
}

@end
