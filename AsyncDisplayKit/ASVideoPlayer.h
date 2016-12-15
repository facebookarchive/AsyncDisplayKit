//
//  ASVideoPlayer.h
//  ASVideoPlayer
//
//  Created by Wojciech Czekalski on 01.12.2016.
//  Copyright © 2016 wokalski. All rights reserved.
//

@import AVFoundation;

typedef enum : NSUInteger {
    ASPlayerFailureSomeReason
} ASPlayerFailureReason;

typedef enum : NSUInteger {
    ASVideoPlayerStatusNoItem,
    ASVideoPlayerStatusLoading,
    ASVideoPlayerStatusReadyToPlay,
    ASVideoPlayerStatusPlaying,
    ASVideoPlayerStatusPaused,
} ASVideoPlayerStatus;

typedef enum : NSUInteger {
    ASVideoPlayerLoadingErrorNone,
    // It either means that an URL is not a file:// URL, it is a remote asset, or is not a valid URL at all
    ASVideoPlayerLoadingErrorInvalidURL,
    ASVideoPlayerLoadingErrorAssetNotFound,
    ASVideoPlayerLoadingErrorUnknown
} ASVideoPlayerLoadingError;

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ASVideoPlayerPlaybackErrorNone,
    ASVideoPlayerPlaybackErrorNotReady,
    ASVideoPlayerPlaybackErrorNoLayer,
} ASVideoPlayerPlaybackError;

typedef void (^PlaybackError)(BOOL success, ASVideoPlayerPlaybackError error);

typedef void (^AssetLoadingCompletionHandler)(BOOL success, ASVideoPlayerLoadingError error, NSError * _Nullable externalError);

@interface ASVideoPlayer : NSObject

// Playback control
//@property (nonatomic, weak, readonly) AVSampleBufferDisplayLayer *layer;

@property (nonatomic, readonly) ASVideoPlayerStatus status;
@property (nonatomic, strong, readonly, nullable) AVAsset *asset;

@property (nonatomic, strong, readonly, nullable) AVAssetReader *reader;
@property (nonatomic, strong, readonly, nullable) AVAssetReaderTrackOutput *videoOutput;
@property (nonatomic, strong, readonly, nullable) AVAssetReaderTrackOutput *audioOutput;

@property (nonatomic, strong, nullable) AVSampleBufferDisplayLayer *playerLayer;

/// Sets playback rate of the player. Reset after calling `loadAsset:completionHandler:` to 1.
@property (nonatomic) Float64 rate;
@property (nonatomic) int64_t time;

- (void)loadAsset:(AVAsset *)asset completionHandler:(nullable AssetLoadingCompletionHandler)completionHandler;
- (ASVideoPlayerPlaybackError)play;
- (void)pause;

@end

NS_ASSUME_NONNULL_END
