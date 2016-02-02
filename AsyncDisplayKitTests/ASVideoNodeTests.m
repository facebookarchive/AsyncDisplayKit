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
{
  ASVideoNode *_videoNode;
  AVAsset *_firstAsset;
  AVAsset *_secondAsset;
}
@end

@interface ASVideoNode () {
  ASDisplayNode *_playerNode;
}
@property (atomic) ASInterfaceState interfaceState;
@property (atomic) ASDisplayNode *spinner;
@property (atomic) ASDisplayNode *playerNode;
@property (atomic) BOOL shouldBePlaying;

- (void)setPlayerNode:(ASDisplayNode *)playerNode;
@end

@implementation ASVideoNode (Test)

- (void)setPlayerNode:(ASDisplayNode *)playerNode
{
  _playerNode = playerNode;
}

@end

@implementation ASVideoNodeTests

- (void)setUp
{
  _videoNode = [[ASVideoNode alloc] init];
  _firstAsset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  _secondAsset = [AVAsset assetWithURL:[NSURL URLWithString:@"secondURL"]];
}

- (void)testVideoNodeReplacesAVPlayerItemWhenNewURLIsSet
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  _videoNode.asset = _firstAsset;
  
  AVPlayerItem *item = [_videoNode currentItem];
  
  _videoNode.asset = _secondAsset;
  AVPlayerItem *secondItem = [_videoNode currentItem];
  
  XCTAssertNotEqualObjects(item, secondItem);
}

- (void)testVideoNodeDoesNotReplaceAVPlayerItemWhenSameURLIsSet
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;

  _videoNode.asset = _firstAsset;
  AVPlayerItem *item = [_videoNode currentItem];
  
  _videoNode.asset = _firstAsset;
  AVPlayerItem *secondItem = [_videoNode currentItem];
  
  XCTAssertEqualObjects(item, secondItem);
}

- (void)testSpinnerDefaultsToNil
{
  XCTAssertNil(_videoNode.spinner);
}

- (void)testOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnode
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  _videoNode.asset = _firstAsset;
  
  [_videoNode play];
  
  XCTAssertNotNil(_videoNode.spinner);
}

- (void)testOnPauseSpinnerIsPausedIfPresent
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  _videoNode.asset = _firstAsset;
  
  [_videoNode play];
  
  [_videoNode pause];
  
  XCTAssertFalse(((UIActivityIndicatorView *)_videoNode.spinner.view).isAnimating);
}

- (void)testOnVideoReadySpinnerIsStoppedAndRemoved
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  _videoNode.asset = _firstAsset;

  [_videoNode play];
  [_videoNode observeValueForKeyPath:@"status" ofObject:[_videoNode currentItem] change:@{@"new" : @(AVPlayerItemStatusReadyToPlay)} context:NULL];
  
  XCTAssertFalse(((UIActivityIndicatorView *)_videoNode.spinner.view).isAnimating);
}

- (void)testPlayerDefaultsToNil
{
  XCTAssertNil(_videoNode.player);
}

- (void)testPlayerIsCreatedInFetchData
{
  _videoNode.asset = _firstAsset;

  _videoNode.interfaceState = ASInterfaceStateFetchData;
  
  XCTAssertNotNil(_videoNode.player);
}

- (void)testPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlaying
{
  _videoNode.asset = _firstAsset;

  [_videoNode setInterfaceState:ASInterfaceStateNone];
  [_videoNode didLoad];
  
  XCTAssert(![_videoNode.subnodes containsObject:_videoNode.playerNode]);
}

- (void)testPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlaying
{
  _videoNode.asset = _firstAsset;

  [_videoNode pause];
  [_videoNode setInterfaceState:ASInterfaceStateVisible];
  [_videoNode didLoad];
  
  XCTAssert(![_videoNode.subnodes containsObject:_videoNode.playerNode]);
}


- (void)testVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay
{
  _videoNode.asset = _firstAsset;
  _videoNode.shouldAutoplay = YES;
  _videoNode.playerNode = [[ASDisplayNode alloc] initWithLayerBlock:^CALayer *{
    AVPlayerLayer *playerLayer = [[AVPlayerLayer alloc] init];
    return playerLayer;
  }];
  _videoNode.playerNode.layer.frame = CGRectZero;
  
  [_videoNode visibilityDidChange:YES];

  XCTAssertTrue(_videoNode.shouldBePlaying);
}

- (void)testVideoShouldPauseWhenItLeavesVisibleButShouldKnowPlayingShouldRestartLater
{
  _videoNode.asset = _firstAsset;
  [_videoNode play];
  
  [_videoNode interfaceStateDidChange:ASInterfaceStateNone fromState:ASInterfaceStateVisible];

  XCTAssertFalse(_videoNode.isPlaying);
  XCTAssertTrue(_videoNode.shouldBePlaying);
}

- (void)testVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBack
{
  _videoNode.asset = _firstAsset;
  [_videoNode play];
  
  [_videoNode interfaceStateDidChange:ASInterfaceStateVisible fromState:ASInterfaceStateNone];
  [_videoNode interfaceStateDidChange:ASInterfaceStateNone fromState:ASInterfaceStateVisible];
  
  XCTAssertTrue(_videoNode.shouldBePlaying);
}

@end
