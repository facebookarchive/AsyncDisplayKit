/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ASVideoNode.h"

@interface ASVideoNodeTests : XCTestCase

@end

@implementation ASVideoNodeTests

- (void)testVideoNodeReplacesAVPlayerWhenNewURLIsSet {
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  [videoNode fetchData];
  AVPlayer *player = ((AVPlayerLayer *)videoNode.layer).player;
  
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"secondURL"]];
  [videoNode fetchData];
  AVPlayer *secondPlayer = ((AVPlayerLayer *)videoNode.layer).player;
 
  XCTAssertNotEqualObjects(player, secondPlayer);
}

- (void)testVideoNodeDoesNotMakeNewPlayerWhenURLIsTheSame {
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  [videoNode fetchData];
  
  AVPlayer *firstPlayer = ((AVPlayerLayer *)videoNode.layer).player;
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];

  AVPlayer *secondPlayer = ((AVPlayerLayer *)videoNode.layer).player;
  
  XCTAssertEqualObjects(firstPlayer, secondPlayer);
}

@end
