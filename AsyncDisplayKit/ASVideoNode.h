/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#if TARGET_OS_IOS
#import <AsyncDisplayKit/ASButtonNode.h>

@class AVAsset, AVPlayer, AVPlayerItem;
@protocol ASVideoNodeDelegate;

typedef enum {
  ASVideoNodePlayerStateUnknown,
  ASVideoNodePlayerStatePlaying,
  ASVideoNodePlayerStateLoading,
  ASVideoNodePlayerStatePaused,
  ASVideoNodePlayerStateFinished
} ASVideoNodePlayerState;

NS_ASSUME_NONNULL_BEGIN

// IMPORTANT NOTES:
// 1. Applications using ASVideoNode must link AVFoundation! (this provides the AV* classes below)
// 2. This is a relatively new component of AsyncDisplayKit.  It has many useful features, but
//    there is room for further expansion and optimization.  Please report any issues or requests
//    in an issue on GitHub: https://github.com/facebook/AsyncDisplayKit/issues

@interface ASVideoNode : ASControlNode

- (void)play;
- (void)pause;
- (BOOL)isPlaying;

@property (nullable, atomic, strong, readwrite) AVAsset *asset;

@property (nullable, atomic, strong, readonly) AVPlayer *player;
@property (nullable, atomic, strong, readonly) AVPlayerItem *currentItem;

/**
 * When shouldAutoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
 * If it leaves the visible interfaceState it will pause but will resume once it has returned.
 */
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (nonatomic, assign, readwrite) BOOL shouldAutorepeat;

@property (nonatomic, assign, readwrite) BOOL muted;

@property (nonatomic, assign, readonly) ASVideoNodePlayerState playerState;
//! Defaults to 100
@property (nonatomic, assign) int32_t periodicTimeObserverTimescale;

//! Defaults to AVLayerVideoGravityResizeAspect
@property (atomic) NSString *gravity;

//! Defaults to an ASDefaultPlayButton instance.
@property (nullable, atomic) ASButtonNode *playButton;

@property (nullable, atomic, weak, readwrite) id<ASVideoNodeDelegate> delegate;

@end

@protocol ASVideoNodeDelegate <NSObject>
@optional
/**
 * @abstract Delegate method invoked when the node's video has played to its end time.
 * @param videoNode The video node has played to its end time.
 */
- (void)videoPlaybackDidFinish:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked the node is tapped.
 * @param videoNode The video node that was tapped.
 * @discussion The video's play state is toggled if this method is not implemented.
 */
- (void)videoNodeWasTapped:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when player changes state.
 * @param videoNode The video node that was tapped.
 * @param state player state before this change.
 * @param toSate player new state.
 * @discussion This method is called after each state change
 */
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toSate;
/**
 * @abstract Ssks delegate if state change is allowed
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused.
 * asks delegate if state change is allowed.
 * @param videoNode The video node that was tapped.
 * @param state player state that is going to be set.
 * @discussion Delegate method invoked when player changes it's state to
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused 
 * and asks delegate if state change is valid
 */
- (BOOL)videoNode:(ASVideoNode*)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state;
/**
 * @abstract Delegate method invoked when player playback time is updated.
 * @param videoNode The video node that was tapped.
 * @param second current playback time in seconds.
 */
- (void)videoNode:(ASVideoNode *)videoNode didPlayToSecond:(NSTimeInterval)second;
@end
NS_ASSUME_NONNULL_END
#endif
