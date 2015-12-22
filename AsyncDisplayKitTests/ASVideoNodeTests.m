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

@interface ASVideoNode ()
@property (atomic, readonly) AVPlayerItem *currentItem;
@property (atomic) ASInterfaceState interfaceState;
@property (atomic) ASDisplayNode *spinner;
@end

@interface AVPlayerItem ()
@property (nonatomic) AVPlayerItemStatus status;
@end

@implementation ASVideoNodeTests

- (void)testVideoNodeReplacesAVPlayerItemWhenNewURLIsSet
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.interfaceState = ASInterfaceStateFetchData;
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  
  AVPlayerItem *item = [videoNode currentItem];
  
  videoNode.asset = [AVAsset assetWithURL:[NSURL URLWithString:@"secondURL"]];
  AVPlayerItem *secondItem = [videoNode currentItem];
  
  XCTAssertNotEqualObjects(item, secondItem);
}

- (void)testVideoNodeDoesNotReplaceAVPlayerItemWhenSameURLIsSet
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.interfaceState = ASInterfaceStateFetchData;
  AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];

  videoNode.asset = asset;
  AVPlayerItem *item = [videoNode currentItem];
  
  videoNode.asset = asset;
  AVPlayerItem *secondItem = [videoNode currentItem];
  
  XCTAssertEqualObjects(item, secondItem);
}

//Touch Handling

- (void)testSpinnerDefaultsToNil
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  
  XCTAssertNil(videoNode.spinner);
}

- (void)testOnPlayIfVideoIsNotReadyInitializeSpinnerAndAddAsSubnode
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.interfaceState = ASInterfaceStateFetchData;
  AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  videoNode.asset = asset;
  
  [videoNode play];
  
  XCTAssertNotNil(videoNode.spinner);
}

- (void)testOnPauseSpinnerIsPausedIfPresent
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.interfaceState = ASInterfaceStateFetchData;
  AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  videoNode.asset = asset;
  
  [videoNode play];
  
  [videoNode pause];
  
  XCTAssertFalse(((UIActivityIndicatorView *)videoNode.spinner.view).isAnimating);
}

- (void)testOnVideoReadySpinnerIsStoppedAndRemoved
{
  ASVideoNode *videoNode = [[ASVideoNode alloc] init];
  videoNode.interfaceState = ASInterfaceStateFetchData;
  AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"firstURL"]];
  videoNode.asset = asset;

  [videoNode play];
  [videoNode observeValueForKeyPath:@"status" ofObject:[videoNode currentItem] change:@{@"new" : @(AVPlayerItemStatusReadyToPlay)} context:NULL];
  
  XCTAssertFalse(((UIActivityIndicatorView *)videoNode.spinner.view).isAnimating);
}

- (void)testPlayButtonUserInteractionIsNotEnabled
{
  
}

@end
