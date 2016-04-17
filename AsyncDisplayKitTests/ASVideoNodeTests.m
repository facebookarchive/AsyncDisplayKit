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
}
@end

@interface ASVideoNode ()

@property (atomic) ASInterfaceState interfaceState;
@property (atomic, readonly) ASDisplayNode *spinner;
@property (atomic, readonly) ASDisplayNode *playerNode;
@property (atomic, readonly) ASImageNode *placeholderImageNode;
@property (atomic, readwrite) AVPlayer *player;
@property (atomic, readonly) BOOL shouldBePlaying;

- (void)setPlaceholderImage:(UIImage *)image;
@end

@implementation ASVideoNodeTests

- (void)setUp
{
  _videoNode = [[ASVideoNode alloc] init];
  _firstAsset = [AVURLAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
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
  
  _videoNode.asset = [AVAsset assetWithURL:_firstAsset.URL];
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
  [_videoNode observeValueForKeyPath:@"status" ofObject:[_videoNode currentItem] change:@{NSKeyValueChangeNewKey : @(AVPlayerItemStatusReadyToPlay)} context:NULL];
  
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
  [_videoNode setInterfaceState:ASInterfaceStateVisible | ASInterfaceStateDisplay];
  [_videoNode didLoad];
  
  XCTAssert(![_videoNode.subnodes containsObject:_videoNode.playerNode]);
}

- (void)testVideoStartsPlayingOnDidDidBecomeVisibleWhenShouldAutoplay
{
  _videoNode.asset = _firstAsset;
  _videoNode.shouldAutoplay = YES;
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

- (void)testSettingVideoGravityChangesPlaceholderContentMode
{
  [_videoNode setPlaceholderImage:[[UIImage alloc] init]];
  XCTAssertEqual(UIViewContentModeScaleAspectFit, _videoNode.placeholderImageNode.contentMode);

  _videoNode.gravity = AVLayerVideoGravityResize;
  XCTAssertEqual(UIViewContentModeScaleToFill, _videoNode.placeholderImageNode.contentMode);

  _videoNode.gravity = AVLayerVideoGravityResizeAspect;
  XCTAssertEqual(UIViewContentModeScaleAspectFit, _videoNode.placeholderImageNode.contentMode);

  _videoNode.gravity = AVLayerVideoGravityResizeAspectFill;
  XCTAssertEqual(UIViewContentModeScaleAspectFill, _videoNode.placeholderImageNode.contentMode);
}

- (void)testChangingAssetsChangesPlaceholderImage
{
  UIImage *firstImage = [[UIImage alloc] init];

  _videoNode.asset = _firstAsset;
  [_videoNode setPlaceholderImage:firstImage];
  XCTAssertEqual(firstImage, _videoNode.placeholderImageNode.image);

  _videoNode.asset = _secondAsset;
  XCTAssertNotEqual(firstImage, _videoNode.placeholderImageNode.image);
}

- (void)testClearingFetchedContentShouldClearAssetData
{
  _videoNode.asset = _firstAsset;
  [_videoNode fetchData];
  [_videoNode setPlaceholderImage:[[UIImage alloc] init]];
  XCTAssertNotNil(_videoNode.player);
  XCTAssertNotNil(_videoNode.currentItem);
  XCTAssertNotNil(_videoNode.placeholderImageNode.image);

  [_videoNode clearFetchedData];
  XCTAssertNil(_videoNode.player);
  XCTAssertNil(_videoNode.currentItem);
  XCTAssertNil(_videoNode.placeholderImageNode.image);
}

- (void)testChangingPlayButtonPerformsProperCleanup
{
  ASButtonNode *firstButton = _videoNode.playButton;
  XCTAssertTrue([firstButton.allTargets containsObject:_videoNode]);

  ASButtonNode *secondButton = [[ASButtonNode alloc] init];
  _videoNode.playButton = secondButton;

  XCTAssertTrue([secondButton.allTargets containsObject:_videoNode]);
  XCTAssertEqual(_videoNode, secondButton.supernode);

  XCTAssertFalse([firstButton.allTargets containsObject:_videoNode]);
  XCTAssertNotEqual(_videoNode, firstButton.supernode);
}

- (void)testVideoThatDoesNotAutorepeatsShouldPauseOnPlaybackEnd
{
  _videoNode.asset = _firstAsset;
  _videoNode.shouldAutorepeat = NO;

  [_videoNode didLoad];
  [_videoNode setInterfaceState:ASInterfaceStateVisible | ASInterfaceStateDisplay | ASInterfaceStateFetchData];
  [_videoNode play];

  XCTAssertTrue(_videoNode.isPlaying);

  [[NSNotificationCenter defaultCenter] postNotificationName:AVPlayerItemDidPlayToEndTimeNotification object:_videoNode.currentItem];

  XCTAssertFalse(_videoNode.isPlaying);
  XCTAssertEqual(0, CMTimeGetSeconds(_videoNode.player.currentTime));
}

- (void)testVideoThatAutorepeatsShouldRepeatOnPlaybackEnd
{
  _videoNode.asset = _firstAsset;
  _videoNode.shouldAutorepeat = YES;

  [_videoNode didLoad];
  [_videoNode setInterfaceState:ASInterfaceStateVisible | ASInterfaceStateDisplay | ASInterfaceStateFetchData];
  [_videoNode play];

  [[NSNotificationCenter defaultCenter] postNotificationName:AVPlayerItemDidPlayToEndTimeNotification object:_videoNode.currentItem];

  XCTAssertTrue(_videoNode.isPlaying);
}

- (void)testBackgroundingAndForegroungingTheAppShouldPauseAndResume
{
  _videoNode.asset = _firstAsset;

  [_videoNode didLoad];
  [_videoNode setInterfaceState:ASInterfaceStateVisible | ASInterfaceStateDisplay | ASInterfaceStateFetchData];
  [_videoNode play];

  XCTAssertTrue(_videoNode.isPlaying);

  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil];

  XCTAssertFalse(_videoNode.isPlaying);

  [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillEnterForegroundNotification object:nil];

  XCTAssertTrue(_videoNode.isPlaying);
}

@end
