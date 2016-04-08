/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASButtonNode.h>

@class AVAsset, AVPlayer, AVPlayerItem;
@protocol ASVideoNodeDelegate;

NS_ASSUME_NONNULL_BEGIN

// IMPORTANT NOTES:
// 1. Applications using ASVideoNode must link AVFoundation! (this provides the AV* classes below)
// 2. This is a relatively new component of AsyncDisplayKit.  It has many useful features, but
//    there is room for further expansion and optimization.  Please report any issues or requests
//    in an issue on GitHub: https://github.com/facebook/AsyncDisplayKit/issues

@interface ASVideoNode : ASControlNode
@property (nullable, atomic, strong) AVAsset *asset;
@property (nullable, atomic, strong, readonly) AVPlayer *player;
@property (nullable, atomic, strong, readonly) AVPlayerItem *currentItem;

/** 
* When shouldAutoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
* If it leaves the visible interfaceState it will pause but will resume once it has returned.
*/
@property (nonatomic) BOOL shouldAutoplay;
@property (nonatomic) BOOL shouldAutorepeat;
@property (nonatomic) BOOL muted;

//! Defaults to AVLayerVideoGravityResizeAspect
@property (atomic, strong) NSString *gravity;

//! Defaults to an ASDefaultPlayButton instance.
@property (nullable, atomic, strong) ASButtonNode *playButton;

@property (nullable, atomic, weak) id<ASVideoNodeDelegate> delegate;

- (void)play;
- (void)pause;

- (BOOL)isPlaying;

@end

@protocol ASVideoNodeDelegate <NSObject>
@optional
- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode;
- (void)videoNodeWasTapped:(ASVideoNode *)videoNode;
@end

NS_ASSUME_NONNULL_END
