/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASVideoNodeTests : XCTestCase
{
  ASVideoNode *_videoNode;
  AVURLAsset *_firstAsset;
  AVAsset *_secondAsset;
  NSURL *_url;
}
@end

@interface ASVideoNode () {
  ASDisplayNode *_playerNode;
  AVPlayer *_player;
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

- (void)setPlayer:(AVPlayer *)player
{
  _player = player;
}

@end

@implementation ASVideoNodeTests

- (void)setUp
{
  _videoNode = [[ASVideoNode alloc] init];
  _firstAsset = [AVURLAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  _secondAsset = [AVAsset assetWithURL:[NSURL URLWithString:@"secondURL"]];
  _url = [NSURL URLWithString:@"testURL"];
}


- (void)testSpinnerDefaultsToNil
{
  XCTAssertNil(_videoNode.spinner);
}


- (void)testOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnode
{
  _videoNode.asset = _firstAsset;
  [self doOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnodeWithUrl];
}

- (void)testOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnodeWithUrl
{
  _videoNode.url = _url;
  [self doOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnodeWithUrl];
}

- (void)doOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnodeWithUrl
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  [_videoNode play];
  
  XCTAssertNotNil(_videoNode.spinner);
}


- (void)testOnPauseSpinnerIsPausedIfPresent
{
  _videoNode.asset = _firstAsset;
  [self doOnPauseSpinnerIsPausedIfPresentWithURL];
}

- (void)testOnPauseSpinnerIsPausedIfPresentWithURL
{
  _videoNode.url = _url;
  [self doOnPauseSpinnerIsPausedIfPresentWithURL];
}

- (void)doOnPauseSpinnerIsPausedIfPresentWithURL
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  
  [_videoNode play];
  [_videoNode pause];
  
  XCTAssertFalse(((UIActivityIndicatorView *)_videoNode.spinner.view).isAnimating);
}


- (void)testOnVideoReadySpinnerIsStoppedAndRemoved
{
  _videoNode.asset = _firstAsset;
  [self doOnVideoReadySpinnerIsStoppedAndRemovedWithURL];
}

- (void)testOnVideoReadySpinnerIsStoppedAndRemovedWithURL
{
  _videoNode.url = _url;
  [self doOnVideoReadySpinnerIsStoppedAndRemovedWithURL];
}

- (void)doOnVideoReadySpinnerIsStoppedAndRemovedWithURL
{
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  
  [_videoNode play];
  [_videoNode observeValueForKeyPath:@"status" ofObject:[_videoNode currentItem] change:@{@"new" : @(AVPlayerItemStatusReadyToPlay)} context:NULL];
  
  XCTAssertFalse(((UIActivityIndicatorView *)_videoNode.spinner.view).isAnimating);
}


- (void)testPlayerDefaultsToNil
{
  _videoNode.asset = _firstAsset;
  XCTAssertNil(_videoNode.player);
}

- (void)testPlayerDefaultsToNilWithURL
{
  _videoNode.url = _url;
  XCTAssertNil(_videoNode.player);
}

- (void)testPlayerIsCreatedInFetchData
{
  _videoNode.asset = _firstAsset;
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  
  XCTAssertNotNil(_videoNode.player);
}

- (void)testPlayerIsCreatedInFetchDataWithURL
{
  _videoNode.url = _url;
  _videoNode.interfaceState = ASInterfaceStateFetchData;
  
  XCTAssertNotNil(_videoNode.player);
}


- (void)testPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlaying
{
  _videoNode.asset = _firstAsset;
  [self doPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlayingWithURL];
}

- (void)testPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlayingWithURL
{
  _videoNode.url = _url;
  [self doPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlayingWithURL];
}

- (void)doPlayerLayerNodeIsAddedOnDidLoadIfVisibleAndAutoPlayingWithURL
{
  [_videoNode setInterfaceState:ASInterfaceStateNone];
  [_videoNode didLoad];
  
  XCTAssert(![_videoNode.subnodes containsObject:_videoNode.playerNode]);
}


- (void)testPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlaying
{
  _videoNode.asset = _firstAsset;
  [self doPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlaying];
}

- (void)testPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlayingWithUrl
{
  _videoNode.url = _url;
  [self doPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlaying];
}

- (void)doPlayerLayerNodeIsNotAddedIfVisibleButShouldNotBePlaying
{
  [_videoNode pause];
  [_videoNode setInterfaceState:ASInterfaceStateVisible | ASInterfaceStateDisplay];
  [_videoNode didLoad];
  
  XCTAssert(![_videoNode.subnodes containsObject:_videoNode.playerNode]);
}


- (void)testVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay
{
  _videoNode.asset = _firstAsset;
  [self doVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay];
}

- (void)testVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplayWithURL
{
  _videoNode.url = _url;
  [self doVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay];
}

- (void)doVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay
{
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
  [self doVideoShouldPauseWhenItLeavesVisibleButShouldKnowPlayingShouldRestartLater];
}

- (void)testVideoShouldPauseWhenItLeavesVisibleButShouldKnowPlayingShouldRestartLaterWithURL
{
  _videoNode.url = _url;
  [self doVideoShouldPauseWhenItLeavesVisibleButShouldKnowPlayingShouldRestartLater];
}

- (void)doVideoShouldPauseWhenItLeavesVisibleButShouldKnowPlayingShouldRestartLater
{
  [_videoNode play];
  
  [_videoNode interfaceStateDidChange:ASInterfaceStateNone fromState:ASInterfaceStateVisible];

  XCTAssertFalse(_videoNode.isPlaying);
  XCTAssertTrue(_videoNode.shouldBePlaying);
}


- (void)testVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBack
{
  _videoNode.asset = _firstAsset;
  [self doVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBack];
}

- (void)testVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBackWithURL
{
  _videoNode.url = _url;
  [self doVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBack];
}

- (void)doVideoThatIsPlayingWhenItLeavesVisibleRangeStartsAgainWhenItComesBack
{
  [_videoNode play];
  
  [_videoNode interfaceStateDidChange:ASInterfaceStateVisible fromState:ASInterfaceStateNone];
  [_videoNode interfaceStateDidChange:ASInterfaceStateNone fromState:ASInterfaceStateVisible];
  
  XCTAssertTrue(_videoNode.shouldBePlaying);
}

- (void)testMutingShouldMutePlayer
{
  [_videoNode setPlayer:[[AVPlayer alloc] init]];

  _videoNode.muted = YES;

  XCTAssertTrue(_videoNode.player.muted);
}

- (void)testUnMutingShouldUnMutePlayer
{
  [_videoNode setPlayer:[[AVPlayer alloc] init]];

  _videoNode.muted = YES;
  _videoNode.muted = NO;

  XCTAssertFalse(_videoNode.player.muted);
}

@end
