//
//  ASVideoPlayerNode.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if TARGET_OS_IOS
#import <CoreMedia/CoreMedia.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASVideoNode.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@class AVAsset;
@class ASButtonNode;
@protocol ASVideoPlayerNodeDelegate;

typedef NS_ENUM(NSInteger, ASVideoPlayerNodeControlType) {
  ASVideoPlayerNodeControlTypePlaybackButton,
  ASVideoPlayerNodeControlTypeElapsedText,
  ASVideoPlayerNodeControlTypeDurationText,
  ASVideoPlayerNodeControlTypeScrubber,
  ASVideoPlayerNodeControlTypeFullScreenButton,
  ASVideoPlayerNodeControlTypeFlexGrowSpacer,
};

NS_ASSUME_NONNULL_BEGIN

@interface ASVideoPlayerNode : ASDisplayNode

@property (nullable, nonatomic, weak) id<ASVideoPlayerNodeDelegate> delegate;

@property (nonatomic, assign, readonly) CMTime duration;

@property (nonatomic, assign) BOOL controlsDisabled;

@property (nonatomic, assign, readonly) BOOL loadAssetWhenNodeBecomesVisible ASDISPLAYNODE_DEPRECATED_MSG("Asset is always loaded when this node enters preload state. This flag does nothing.");

#pragma mark - ASVideoNode property proxy
/**
 * When shouldAutoplay is set to true, a video node will play when it has both loaded and entered the "visible" interfaceState.
 * If it leaves the visible interfaceState it will pause but will resume once it has returned.
 */
@property (nonatomic, assign, readwrite) BOOL shouldAutoPlay;
@property (nonatomic, assign, readwrite) BOOL shouldAutoRepeat;
@property (nonatomic, assign, readwrite) BOOL muted;
@property (nonatomic, assign, readonly) ASVideoNodePlayerState playerState;
@property (nonatomic, assign, readwrite) BOOL shouldAggressivelyRecoverFromStall;
@property (nullable, nonatomic, strong, readwrite) NSURL *placeholderImageURL;

@property (nullable, nonatomic, strong, readwrite) AVAsset *asset;
/**
 ** @abstract The URL with which the asset was initialized.
 ** @discussion Setting the URL will override the current asset with a newly created AVURLAsset created from the given URL, and AVAsset *asset will point to that newly created AVURLAsset.  Please don't set both assetURL and asset.
 ** @return Current URL the asset was initialized or nil if no URL was given.
 **/
@property (nullable, nonatomic, strong, readwrite) NSURL *assetURL;

/// You should never set any value on the backing video node. Use exclusivively the video player node to set properties
@property (nonatomic, strong, readonly) ASVideoNode *videoNode;

//! Defaults to 100
@property (nonatomic, assign) int32_t periodicTimeObserverTimescale;
//! Defaults to AVLayerVideoGravityResizeAspect
@property (nonatomic, copy) NSString *gravity;

#pragma mark - Lifecycle
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithAsset:(AVAsset *)asset;
- (instancetype)initWithAsset:(AVAsset *)asset videoComposition:(AVVideoComposition *)videoComposition audioMix:(AVAudioMix *)audioMix;

#pragma mark Lifecycle Deprecated
- (instancetype)initWithUrl:(NSURL *)url ASDISPLAYNODE_DEPRECATED_MSG("Asset is always loaded when this node enters preload state, therefore loadAssetWhenNodeBecomesVisible is deprecated and not used anymore.");
- (instancetype)initWithUrl:(NSURL *)url loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible ASDISPLAYNODE_DEPRECATED_MSG("Asset is always loaded when this node enters preload state, therefore loadAssetWhenNodeBecomesVisible is deprecated and not used anymore.");
- (instancetype)initWithAsset:(AVAsset *)asset loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible ASDISPLAYNODE_DEPRECATED_MSG("Asset is always loaded when this node enters preload state, therefore loadAssetWhenNodeBecomesVisible is deprecated and not used anymore.");
- (instancetype)initWithAsset:(AVAsset *)asset videoComposition:(AVVideoComposition *)videoComposition audioMix:(AVAudioMix *)audioMix loadAssetWhenNodeBecomesVisible:(BOOL)loadAssetWhenNodeBecomesVisible ASDISPLAYNODE_DEPRECATED_MSG("Asset is always loaded when this node enters preload state, therefore loadAssetWhenNodeBecomesVisible is deprecated and not used anymore.");

#pragma mark - Public API
- (void)seekToTime:(CGFloat)percentComplete;
- (void)play;
- (void)pause;
- (BOOL)isPlaying;
- (void)resetToPlaceholder;

@end

#pragma mark - ASVideoPlayerNodeDelegate -
@protocol ASVideoPlayerNodeDelegate <NSObject>
@optional
/**
 * @abstract Delegate method invoked before creating controlbar controls
 * @param videoPlayer The sender
 */
- (NSArray *)videoPlayerNodeNeededDefaultControls:(ASVideoPlayerNode*)videoPlayer;

/**
 * @abstract Delegate method invoked before creating default controls, asks delegate for custom controls dictionary.
 * This dictionary must constain only ASDisplayNode subclass objects.
 * @param videoPlayer The sender
 * @discussion - This method is invoked only when developer implements videoPlayerNodeLayoutSpec:forControls:forMaximumSize:
 * and gives ability to add custom constrols to ASVideoPlayerNode, for example mute button.
 */
- (NSDictionary *)videoPlayerNodeCustomControls:(ASVideoPlayerNode*)videoPlayer;

/**
 * @abstract Delegate method invoked in layoutSpecThatFits:
 * @param videoPlayer The sender
 * @param controls - Dictionary of controls which are used in videoPlayer; Dictionary keys are ASVideoPlayerNodeControlType
 * @param maxSize - Maximum size for ASVideoPlayerNode
 * @discussion - Developer can layout whole ASVideoPlayerNode as he wants. ASVideoNode is locked and it can't be changed
 */
- (ASLayoutSpec *)videoPlayerNodeLayoutSpec:(ASVideoPlayerNode *)videoPlayer
                                forControls:(NSDictionary *)controls
                             forMaximumSize:(CGSize)maxSize;

#pragma mark Text delegate methods
/**
 * @abstract Delegate method invoked before creating ASVideoPlayerNodeControlTypeElapsedText and ASVideoPlayerNodeControlTypeDurationText
 * @param videoPlayer The sender
 * @param timeLabelType The of the time label
 */
- (NSDictionary *)videoPlayerNodeTimeLabelAttributes:(ASVideoPlayerNode *)videoPlayer timeLabelType:(ASVideoPlayerNodeControlType)timeLabelType;
- (NSString *)videoPlayerNode:(ASVideoPlayerNode *)videoPlayerNode
   timeStringForTimeLabelType:(ASVideoPlayerNodeControlType)timeLabelType
                      forTime:(CMTime)time;

#pragma mark Scrubber delegate methods
- (UIColor *)videoPlayerNodeScrubberMaximumTrackTint:(ASVideoPlayerNode *)videoPlayer;
- (UIColor *)videoPlayerNodeScrubberMinimumTrackTint:(ASVideoPlayerNode *)videoPlayer;
- (UIColor *)videoPlayerNodeScrubberThumbTint:(ASVideoPlayerNode *)videoPlayer;
- (UIImage *)videoPlayerNodeScrubberThumbImage:(ASVideoPlayerNode *)videoPlayer;

#pragma mark - Spinner delegate methods
- (UIColor *)videoPlayerNodeSpinnerTint:(ASVideoPlayerNode *)videoPlayer;
- (UIActivityIndicatorViewStyle)videoPlayerNodeSpinnerStyle:(ASVideoPlayerNode *)videoPlayer;

#pragma mark - Playback button delegate methods
- (UIColor *)videoPlayerNodePlaybackButtonTint:(ASVideoPlayerNode *)videoPlayer;

#pragma mark - Fullscreen button delegate methods

- (UIImage *)videoPlayerNodeFullScreenButtonImage:(ASVideoPlayerNode *)videoPlayer;


#pragma mark ASVideoNodeDelegate proxy methods
/**
 * @abstract Delegate method invoked when ASVideoPlayerNode is taped.
 * @param videoPlayer The ASVideoPlayerNode that was tapped.
 */
- (void)didTapVideoPlayerNode:(ASVideoPlayerNode *)videoPlayer;

/**
 * @abstract Delegate method invoked when fullcreen button is taped.
 * @param buttonNode The fullscreen button node that was tapped.
 */
- (void)didTapFullScreenButtonNode:(ASButtonNode *)buttonNode;

/**
 * @abstract Delegate method invoked when ASVideoNode playback time is updated.
 * @param videoPlayer The video player node
 * @param time current playback time.
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer didPlayToTime:(CMTime)time;

/**
 * @abstract Delegate method invoked when ASVideoNode changes state.
 * @param videoPlayer The ASVideoPlayerNode whose ASVideoNode is changing state.
 * @param state ASVideoNode state before this change.
 * @param toState ASVideoNode new state.
 * @discussion This method is called after each state change
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer willChangeVideoNodeState:(ASVideoNodePlayerState)state toVideoNodeState:(ASVideoNodePlayerState)toState;

/**
 * @abstract Delegate method is invoked when ASVideoNode decides to change state.
 * @param videoPlayer The ASVideoPlayerNode whose ASVideoNode is changing state.
 * @param state ASVideoNode that is going to be set.
 * @discussion Delegate method invoked when player changes it's state to
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused
 * and asks delegate if state change is valid
 */
- (BOOL)videoPlayerNode:(ASVideoPlayerNode*)videoPlayer shouldChangeVideoNodeStateTo:(ASVideoNodePlayerState)state;

/**
 * @abstract Delegate method invoked when the ASVideoNode has played to its end time.
 * @param videoPlayer The video node has played to its end time.
 */
- (void)videoPlayerNodeDidPlayToEnd:(ASVideoPlayerNode *)videoPlayer;

/**
 * @abstract Delegate method invoked when the ASVideoNode has constructed its AVPlayerItem for the asset.
 * @param videoPlayer The video player node.
 * @param currentItem The AVPlayerItem that was constructed from the asset.
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer didSetCurrentItem:(AVPlayerItem *)currentItem;

/**
 * @abstract Delegate method invoked when the ASVideoNode stalls.
 * @param videoPlayer The video player node that has experienced the stall
 * @param timeInterval Current playback time when the stall happens
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer didStallAtTimeInterval:(NSTimeInterval)timeInterval;

/**
 * @abstract Delegate method invoked when the ASVideoNode starts the inital asset loading
 * @param videoPlayer The videoPlayer
 */
- (void)videoPlayerNodeDidStartInitialLoading:(ASVideoPlayerNode *)videoPlayer;

/**
 * @abstract Delegate method invoked when the ASVideoNode is done loading the asset and can start the playback
 * @param videoPlayer The videoPlayer
 */
- (void)videoPlayerNodeDidFinishInitialLoading:(ASVideoPlayerNode *)videoPlayer;

/**
 * @abstract Delegate method invoked when the ASVideoNode has recovered from the stall
 * @param videoPlayer The videoplayer
 */
- (void)videoPlayerNodeDidRecoverFromStall:(ASVideoPlayerNode *)videoPlayer;


@end
NS_ASSUME_NONNULL_END
#endif
