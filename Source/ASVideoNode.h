//
//  ASVideoNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASNetworkImageNode.h>

@class AVAsset, AVPlayer, AVPlayerLayer, AVPlayerItem, AVVideoComposition, AVAudioMix;
@protocol ASVideoNodeDelegate;

typedef NS_ENUM(NSInteger, ASVideoNodePlayerState) {
  ASVideoNodePlayerStateUnknown,
  ASVideoNodePlayerStateInitialLoading,
  ASVideoNodePlayerStateReadyToPlay,
  ASVideoNodePlayerStatePlaybackLikelyToKeepUpButNotPlaying,
  ASVideoNodePlayerStatePlaying,
  ASVideoNodePlayerStateLoading,
  ASVideoNodePlayerStatePaused,
  ASVideoNodePlayerStateFinished
};

NS_ASSUME_NONNULL_BEGIN

// IMPORTANT NOTES:
// 1. Applications using ASVideoNode must link AVFoundation! (this provides the AV* classes below)
// 2. This is a relatively new component of AsyncDisplayKit.  It has many useful features, but
//    there is room for further expansion and optimization.  Please report any issues or requests
//    in an issue on GitHub: https://github.com/facebook/AsyncDisplayKit/issues

@interface ASVideoNode : ASNetworkImageNode

- (void)play;
- (void)pause;
- (BOOL)isPlaying;
- (void)resetToPlaceholder;

@property (nullable, nonatomic, strong, readwrite) AVAsset *asset;
/**
 ** @abstract The URL with which the asset was initialized.
 ** @discussion Setting the URL will override the current asset with a newly created AVURLAsset created from the given URL, and AVAsset *asset will point to that newly created AVURLAsset.  Please don't set both assetURL and asset.
 ** @return Current URL the asset was initialized or nil if no URL was given.
 **/
@property (nullable, nonatomic, strong, readwrite) NSURL *assetURL;
@property (nullable, nonatomic, strong, readwrite) AVVideoComposition *videoComposition;
@property (nullable, nonatomic, strong, readwrite) AVAudioMix *audioMix;

@property (nullable, nonatomic, strong, readonly) AVPlayer *player;
@property (nullable, nonatomic, strong, readonly) AVPlayerLayer *playerLayer;
@property (nullable, nonatomic, strong, readonly) AVPlayerItem *currentItem;


/**
 * When shouldAutoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
 * If it leaves the visible interfaceState it will pause but will resume once it has returned.
 */
@property (nonatomic, assign, readwrite) BOOL shouldAutoplay;
@property (nonatomic, assign, readwrite) BOOL shouldAutorepeat;

@property (nonatomic, assign, readwrite) BOOL muted;
@property (nonatomic, assign, readwrite) BOOL shouldAggressivelyRecoverFromStall;

@property (nonatomic, assign, readonly) ASVideoNodePlayerState playerState;
//! Defaults to 1000
@property (nonatomic, assign) int32_t periodicTimeObserverTimescale;

//! Defaults to AVLayerVideoGravityResizeAspect
@property (nonatomic, copy) NSString *gravity;

@property (nullable, nonatomic, weak, readwrite) id<ASVideoNodeDelegate, ASNetworkImageNodeDelegate> delegate;

@end

@protocol ASVideoNodeDelegate <ASNetworkImageNodeDelegate>
@optional
/**
 * @abstract Delegate method invoked when the node's video has played to its end time.
 * @param videoNode The video node has played to its end time.
 */
- (void)videoDidPlayToEnd:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked the node is tapped.
 * @param videoNode The video node that was tapped.
 * @discussion The video's play state is toggled if this method is not implemented.
 */
- (void)didTapVideoNode:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when player changes state.
 * @param videoNode The video node.
 * @param state player state before this change.
 * @param toState player new state.
 * @discussion This method is called after each state change
 */
- (void)videoNode:(ASVideoNode *)videoNode willChangePlayerState:(ASVideoNodePlayerState)state toState:(ASVideoNodePlayerState)toState;
/**
 * @abstract Ssks delegate if state change is allowed
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused.
 * asks delegate if state change is allowed.
 * @param videoNode The video node.
 * @param state player state that is going to be set.
 * @discussion Delegate method invoked when player changes it's state to
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused 
 * and asks delegate if state change is valid
 */
- (BOOL)videoNode:(ASVideoNode*)videoNode shouldChangePlayerStateTo:(ASVideoNodePlayerState)state;
/**
 * @abstract Delegate method invoked when player playback time is updated.
 * @param videoNode The video node.
 * @param timeInterval current playback time in seconds.
 */
- (void)videoNode:(ASVideoNode *)videoNode didPlayToTimeInterval:(NSTimeInterval)timeInterval;
/**
 * @abstract Delegate method invoked when the video player stalls.
 * @param videoNode The video node that has experienced the stall
 * @param timeInterval Current playback time when the stall happens
 */
- (void)videoNode:(ASVideoNode *)videoNode didStallAtTimeInterval:(NSTimeInterval)timeInterval;
/**
 * @abstract Delegate method invoked when the video player starts the inital asset loading
 * @param videoNode The videoNode
 */
- (void)videoNodeDidStartInitialLoading:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when the video is done loading the asset and can start the playback
 * @param videoNode The videoNode
 */
- (void)videoNodeDidFinishInitialLoading:(ASVideoNode *)videoNode;
/**
 * @abstract Delegate method invoked when the AVPlayerItem for the asset has been set up and can be accessed throught currentItem.
 * @param videoNode The videoNode.
 * @param currentItem The AVPlayerItem that was constructed from the asset.
 */
- (void)videoNode:(ASVideoNode *)videoNode didSetCurrentItem:(AVPlayerItem *)currentItem;
/**
 * @abstract Delegate method invoked when the video node has recovered from the stall
 * @param videoNode The videoNode
 */
- (void)videoNodeDidRecoverFromStall:(ASVideoNode *)videoNode;

@end

@interface ASVideoNode (Unavailable)

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock __unavailable;

@end

NS_ASSUME_NONNULL_END
