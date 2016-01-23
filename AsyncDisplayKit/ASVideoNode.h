/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSUInteger, ASVideoGravity) {
  ASVideoGravityResizeAspect,
  ASVideoGravityResizeAspectFill,
  ASVideoGravityResize
};

@protocol ASVideoNodeDelegate;

// If you need ASVideoNode, please use AsyncDisplayKit master until this comment is removed.
// As of 1.9.6, ASVideoNode accidentally triggers creating the AVPlayerLayer even before playing
// the video.  Using a lot of them intended to show static frame placeholders will be slow.

@interface ASVideoNode : ASControlNode
@property (atomic, strong, readwrite) AVAsset *asset;
@property (atomic, strong, readonly) AVPlayer *player;
@property (atomic, strong, readonly) AVPlayerItem *currentItem;

// When autoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
// If it leaves the visible interfaceState it will pause but will resume once it has returned
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (nonatomic, assign, readwrite) BOOL shouldAutorepeat;

@property (atomic) NSString *gravity;
@property (atomic) ASButtonNode *playButton;

@property (atomic, weak, readwrite) id<ASVideoNodeDelegate> delegate;

- (void)play;
- (void)pause;

- (BOOL)isPlaying;

@end

@protocol ASVideoNodeDelegate <NSObject>
@optional
- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode;
@end

