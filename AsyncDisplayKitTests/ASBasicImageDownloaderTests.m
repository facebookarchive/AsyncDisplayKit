//
//  ASBasicImageDownloaderTests.m
//  AsyncDisplayKit
//
//  Created by Victor Mayorov on 10/06/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASBasicImageDownloader.h>

@interface ASBasicImageDownloaderTests : XCTestCase

@end

@implementation ASBasicImageDownloaderTests

- (void)testAsynchronouslyDownloadTheSameURLTwice
{
  XCTestExpectation *firstExpectation = [self expectationWithDescription:@"First ASBasicImageDownloader completion handler should be called within 3 seconds"];
  XCTestExpectation *secondExpectation = [self expectationWithDescription:@"Second ASBasicImageDownloader completion handler should be called within 3 seconds"];

  ASBasicImageDownloader *downloader = [ASBasicImageDownloader sharedImageDownloader];
  NSURL *URL = [NSURL URLWithString:@"http://wrongPath/wrongResource.png"];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  [downloader downloadImageWithURL:URL
                     callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
             downloadProgressBlock:nil
                        completion:^(CGImageRef image, NSError *error) {
                          [firstExpectation fulfill];
                        }];

  [downloader downloadImageWithURL:URL
                     callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
             downloadProgressBlock:nil
                        completion:^(CGImageRef image, NSError *error) {
                          [secondExpectation fulfill];
                        }];
#pragma clang diagnostic pop

  [self waitForExpectationsWithTimeout:3 handler:nil];
}

@end
