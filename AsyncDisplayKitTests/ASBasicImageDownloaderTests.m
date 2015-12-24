//
//  ASZBasicImageDownloaderTests.m
//  AsyncDisplayKit
//
//  Created by Victor Mayorov on 10/06/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/ASBasicImageDownloader.h>

// Z in the name to delay running until after the test instance is operating normally.
@interface ASBasicImageDownloaderTests : XCTestCase

@end

@implementation ASBasicImageDownloaderTests

- (void)testAsynchronouslyDownloadTheSameURLTwice
{
    ASBasicImageDownloader *downloader = [ASBasicImageDownloader sharedImageDownloader];
    
    NSURL *URL = [NSURL URLWithString:@"http://wrongPath/wrongResource.png"];
  
    __block BOOL firstDone = NO;
    
    [downloader downloadImageWithURL:URL
                       callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
               downloadProgressBlock:nil
                          completion:^(CGImageRef image, NSError *error) {
                              firstDone = YES;
                          }];
    
    __block BOOL secondDone = NO;
    
    [downloader downloadImageWithURL:URL
                       callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
               downloadProgressBlock:nil
                          completion:^(CGImageRef image, NSError *error) {
                              secondDone = YES;
                          }];
  
    sleep(3);
    XCTAssert(firstDone && secondDone, @"Not all ASBasicImageDownloader completion handlers have been called after 3 seconds");
}

@end
