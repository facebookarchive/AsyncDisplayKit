//
//  ASVideoPlayerTests.m
//  ASVideoPlayerTests
//
//  Created by Wojciech Czekalski on 01.12.2016.
//  Copyright © 2016 wokalski. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASVideoPlayer.h"

@interface ASVideoPlayerTests : XCTestCase
@end

@implementation ASVideoPlayerTests

- (void)testInitialStatusUnknown {
    XCTAssertEqual(ASVideoPlayerStatusNoItem, [ASVideoPlayer new].status);
}

- (void)testStatusChangesToLoadingWhenAnAssetIsLoaded {
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    [player loadAsset:asset completionHandler:nil];
    XCTAssertEqual(player.status, ASVideoPlayerStatusLoading);
}

- (void)testLoadsItemIfCompatible {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Loading"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError *externalError) {
        if (success &&
            error == ASVideoPlayerLoadingErrorNone &&
            !error &&
            player.status == ASVideoPlayerStatusReadyToPlay &&
            player.reader &&
            player.videoOutput &&
            player.audioOutput &&
            [player.asset isEqual:asset]) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// TODO: create a mock AVAsset which returns an audio and video track
- (void)testErrorWhenNoSuchItem {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Loading Error"];
    NSURL *randomURL = [NSURL fileURLWithPath:@"invalid url"];
    AVAsset *asset = [AVAsset assetWithURL:randomURL];
    ASVideoPlayer *player = [ASVideoPlayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        if (!success &&
            error == ASVideoPlayerLoadingErrorAssetNotFound &&
            externalError &&
            player.status == ASVideoPlayerStatusNoItem &&
            !player.reader &&
            !player.videoOutput &&
            !player.audioOutput &&
            !player.asset) {
            [expectation fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

// TODO: prepare assets, preferably mocks, subclasses of AVURLAsset
- (void)testErrorWhenItemIncompatible { }
- (void)testErrorIfAudioOnly { }

- (void)testPlayReturnsWhenTheresNoAsset {
    ASVideoPlayer *player = [ASVideoPlayer new];
    ASVideoPlayerPlaybackError error = [player play];
    XCTAssertEqual(error, ASVideoPlayerPlaybackErrorNotReady);
    XCTAssertEqual(player.status, ASVideoPlayerStatusNoItem);
}

- (void)testPlayReturnsWhenTheresNoLayer {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Play no layer"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        ASVideoPlayerPlaybackError playError = [player play];
        if (playError == ASVideoPlayerPlaybackErrorNoLayer &&
            player.status == ASVideoPlayerStatusReadyToPlay) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testPlayPlays {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Play"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    player.playerLayer = [AVSampleBufferDisplayLayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        [player play];
        if (player.status == ASVideoPlayerStatusPlaying &&
            player.reader.status == AVAssetReaderStatusReading) {
            [expectation fulfill];
        }
    }];
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testPlayResumesFromPause {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Resumr"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    player.playerLayer = [AVSampleBufferDisplayLayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        [player play];
        player.rate = 2;
        [player pause];
        [player play];
        if (player.status == ASVideoPlayerStatusPlaying &&
            player.reader.status == AVAssetReaderStatusReading &&
            CMTimebaseGetRate(player.playerLayer.controlTimebase) == 2) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)testPausePauses {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Pause"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    player.playerLayer = [AVSampleBufferDisplayLayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        [player play];
        [player pause];
        if (player.status == ASVideoPlayerStatusPaused &&
            player.reader.status == AVAssetReaderStatusReading &&
            CMTimebaseGetRate(player.playerLayer.controlTimebase) == 0) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}


- (void)testSetRate {
    XCTestExpectation *expectation = [self expectationWithDescription:@"SetRate"];
    AVAsset *asset = [self compatibleAsset];
    ASVideoPlayer *player = [ASVideoPlayer new];
    player.playerLayer = [AVSampleBufferDisplayLayer new];
    [player loadAsset:asset completionHandler:^(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError) {
        [player play];
        player.rate = 2;
        if (player.rate == 2 &&
            player.reader.status == AVAssetReaderStatusReading &&
            CMTimebaseGetRate(player.playerLayer.controlTimebase) == 2) {
            [expectation fulfill];
        }
    }];
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (AVAsset *)compatibleAsset {
    NSURL *url = [[NSBundle bundleForClass:[self class]]
                  URLForResource:@"video"
                  withExtension:@"mp4"
                  subdirectory:@"TestResources"];
    AVAsset *asset = [AVAsset assetWithURL:url];
    return asset;
}

@end
