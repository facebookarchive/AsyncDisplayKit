//
//  ASVideoPlayerNode.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/6/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#if TARGET_OS_IOS
#import <AsyncDisplayKit/AsyncDisplayKit.h>
//#import <AsyncDisplayKit/ASThread.h>
//#import <AsyncDisplayKit/ASVideoNode.h>
//#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

@class AVAsset;
@protocol ASVideoPlayerNodeDelegate;

typedef enum {
  ASVideoPlayerNodeControlTypePlaybackButton,
  ASVideoPlayerNodeControlTypeElapsedText,
  ASVideoPlayerNodeControlTypeDurationText,
  ASVideoPlayerNodeControlTypeScrubber,
  ASVideoPlayerNodeControlTypeFlexGrowSpacer,
} ASVideoPlayerNodeControlType;

NS_ASSUME_NONNULL_BEGIN

@interface ASVideoPlayerNode : ASDisplayNode

@property (nullable, atomic, weak) id<ASVideoPlayerNodeDelegate> delegate;

@property (nonatomic,assign,readonly) CMTime duration;

@property (nonatomic, assign) BOOL disableControls;

#pragma mark - ASVideoNode property proxy
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

- (instancetype)initWithUrl:(NSURL*)url;
- (instancetype)initWithAsset:(AVAsset*)asset;

#pragma mark - Public API
- (void)seekToTime:(CGFloat)percentComplete;
- (void)play;
- (void)pause;
- (BOOL)isPlaying;

@end

#pragma mark - ASVideoPlayerNodeDelegate -
@protocol ASVideoPlayerNodeDelegate <NSObject>
@optional
/**
 * @abstract Delegate method invoked before creating controlbar controls
 * @param videoPlayer
 */
- (NSArray *)videoPlayerNodeNeededControls:(ASVideoPlayerNode*)videoPlayer;

/**
 * @abstract Delegate method invoked in layoutSpecThatFits:
 * @param videoPlayer
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
 * @param videoPlayer
 * @param timeLabelType
 */
- (NSDictionary *)videoPlayerNodeTimeLabelAttributes:(ASVideoPlayerNode *)videoPlayerNode timeLabelType:(ASVideoPlayerNodeControlType)timeLabelType;
- (NSString *)videoPlayerNode:(ASVideoPlayerNode *)videoPlayerNode
   timeStringForTimeLabelType:(ASVideoPlayerNodeControlType)timeLabelType
                      forTime:(CMTime)time;

#pragma mark Scrubber delegate methods
- (UIColor *)videoPlayerNodeScrubberMaximumTrackTint:(ASVideoPlayerNode *)videoPlayer;
- (UIColor *)videoPlayerNodeScrubberMinimumTrackTint:(ASVideoPlayerNode *)videoPlayer;
- (UIColor *)videoPlayerNodeScrubberThumbTint:(ASVideoPlayerNode *)videoPlayer;
- (UIImage *)videoPlayerNodeScrubberThumbImage:(ASVideoPlayerNode *)videoPlayer;

#pragma mark - Playback button delegate methods
- (UIColor *)videoPlayerNodePlaybackButtonTint:(ASVideoPlayerNode *)videoPlayer;


#pragma mark ASVideoNodeDelegate proxy methods
/**
 * @abstract Delegate method invoked when ASVideoPlayerNode playback time is taped.
 * @param videoPlayerNode The ASVideoPlayerNode that was tapped.
 */
- (void)didTapVideoPlayerNode:(ASVideoPlayerNode *)videoPlayer;
/**
 * @abstract Delegate method invoked when ASVideoNode playback time is updated.
 * @param videoPlayerNode The video node that was tapped.
 * @param second current playback time.
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer didPlayToTime:(CMTime)time;

/**
 * @abstract Delegate method invoked when ASVideoNode changes state.
 * @param videoPlayerNode The ASVideoPlayerNode whose ASVideoNode is changing state.
 * @param state ASVideoNode state before this change.
 * @param toSate ASVideoNode new state.
 * @discussion This method is called after each state change
 */
- (void)videoPlayerNode:(ASVideoPlayerNode *)videoPlayer willChangeVideoNodeState:(ASVideoNodePlayerState)state toVideoNodeState:(ASVideoNodePlayerState)toSate;

/**
 * @abstract Delegate method is invoked when ASVideoNode decides to change state.
 * @param videoPlayerNode The ASVideoPlayerNode whose ASVideoNode is changing state.
 * @param state ASVideoNode that is going to be set.
 * @discussion Delegate method invoked when player changes it's state to
 * ASVideoNodePlayerStatePlaying or ASVideoNodePlayerStatePaused
 * and asks delegate if state change is valid
 */
- (BOOL)videoPlayerNode:(ASVideoPlayerNode*)videoPlayer shouldChangeVideoNodeStateTo:(ASVideoNodePlayerState)state;

/**
 * @abstract Delegate method invoked when the ASVideoNode has played to its end time.
 * @param videoPlayerNode The video node has played to its end time.
 */
- (void)videoPlayerNodeDidPlayToEnd:(ASVideoPlayerNode *)videoPlayer;

@end
NS_ASSUME_NONNULL_END
#endif
