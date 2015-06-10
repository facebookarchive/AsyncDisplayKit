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

- (void)testAsynchronouslyDownloadTheSameURLTwice {
    ASBasicImageDownloader *downloader = [ASBasicImageDownloader new];
    
    NSURL *URL = [NSURL URLWithString:@"http://wrongPath/wrongResource.png"];
    
    dispatch_group_t group = dispatch_group_create();
    
    __block BOOL firstDone = NO;
    
    dispatch_group_enter(group);
    [downloader downloadImageWithURL:URL
                       callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
               downloadProgressBlock:nil
                          completion:^(CGImageRef image, NSError *error) {
                              firstDone = YES;
                              dispatch_group_leave(group);
                          }];
    
    __block BOOL secondDone = NO;
    
    dispatch_group_enter(group);
    [downloader downloadImageWithURL:URL
                       callbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
               downloadProgressBlock:nil
                          completion:^(CGImageRef image, NSError *error) {
                              secondDone = YES;
                              dispatch_group_leave(group);
                          }];
    
    XCTAssert(0 == dispatch_group_wait(group, dispatch_time(0, 10 * 1000000000)), @"URL loading takes too long");
    
    XCTAssert(firstDone && secondDone, @"Not all handlers has been called");
}

@end
