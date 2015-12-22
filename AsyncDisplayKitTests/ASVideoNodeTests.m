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

@interface ASVideoNode ()
@property (atomic) ASInterfaceState interfaceState;
@property (atomic) ASDisplayNode *spinner;
@property (atomic) ASDisplayNode *playerNode;
@property (atomic) BOOL shouldBePlaying;
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

//Touch Handling

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

- (void)testPlayerLayerNodeIsAddedOnDisplayDidFinish
{
  _videoNode.asset = _firstAsset;

  [_videoNode displayDidFinish];
  
  XCTAssert([_videoNode.subnodes containsObject:_videoNode.playerNode]);
}

- (void)testVideoStartsPlayingOnDidDisplayIfAutoplayIsSet
{
  _videoNode.asset = _firstAsset;
  _videoNode.shouldAutoplay = YES;
  
  [_videoNode displayDidFinish];
  
  XCTAssertTrue(_videoNode.shouldBePlaying);
}

@end
