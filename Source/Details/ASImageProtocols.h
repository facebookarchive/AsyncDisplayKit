//
//  ASImageProtocols.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASAnimatedImageProtocol;

@protocol ASImageContainerProtocol <NSObject>

- (nullable UIImage *)asdk_image;
- (nullable NSData *)asdk_animatedImageData;

@end

typedef void(^ASImageCacherCompletion)(id <ASImageContainerProtocol> _Nullable imageFromCache);

@protocol ASImageCacheProtocol <NSObject>

/**
 @abstract Attempts to fetch an image with the given URL from the cache.
 @param URL The URL of the image to retrieve from the cache.
 @param callbackQueue The queue to call `completion` on.
 @param completion The block to be called when the cache has either hit or missed.
 @discussion If `URL` is nil, `completion` will be invoked immediately with a nil image. This method should not block
 the calling thread as it is likely to be called from the main thread.
 */
- (void)cachedImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
                completion:(ASImageCacherCompletion)completion;

@optional

/**
 @abstract Attempts to fetch an image with the given URL from a memory cache.
 @param URL The URL of the image to retrieve from the cache.
 @discussion This method exists to support synchronous rendering of nodes. Before the layer is drawn, this method
 is called to attempt to get the image out of the cache synchronously. This allows drawing to occur on the main thread
 if displaysAsynchronously is set to NO or recursivelyEnsureDisplaySynchronously: has been called.
 
 This method *should* block the calling thread to fetch the image from a fast memory cache. It is OK to return nil from
 this method and instead support only cachedImageWithURL:callbackQueue:completion: however, synchronous rendering will
 not be possible.
 */
- (nullable id <ASImageContainerProtocol>)synchronouslyFetchedCachedImageWithURL:(NSURL *)URL;

/**
 @abstract Called during clearPreloadedData. Allows the cache to optionally trim items.
 @note Depending on your caches implementation you may *not* wish to respond to this method. It is however useful
 if you have a memory and disk cache in which case you'll likely want to clear out the memory cache.
 */
- (void)clearFetchedImageFromCacheWithURL:(NSURL *)URL;

@end

/**
 @param image The image that was downloaded, if the image could be successfully downloaded; nil otherwise.
 @param error An error describing why the download of `URL` failed, if the download failed; nil otherwise.
 @param downloadIdentifier The identifier for the download task that completed.
 */
typedef void(^ASImageDownloaderCompletion)(id <ASImageContainerProtocol> _Nullable image, NSError * _Nullable error, id _Nullable downloadIdentifier);

/**
 @param progress The progress of the download, in the range of (0.0, 1.0), inclusive.
 */
typedef void(^ASImageDownloaderProgress)(CGFloat progress);
typedef void(^ASImageDownloaderProgressImage)(UIImage *progressImage, CGFloat progress, id _Nullable downloadIdentifier);

typedef NS_ENUM(NSUInteger, ASImageDownloaderPriority) {
  ASImageDownloaderPriorityPreload = 0,
  ASImageDownloaderPriorityImminent,
  ASImageDownloaderPriorityVisible
};

@protocol ASImageDownloaderProtocol <NSObject>

@required

/**
 @abstract Downloads an image with the given URL.
 @param URL The URL of the image to download.
 @param callbackQueue The queue to call `downloadProgressBlock` and `completion` on.
 @param downloadProgress The block to be invoked when the download of `URL` progresses.
 @param completion The block to be invoked when the download has completed, or has failed.
 @discussion This method is likely to be called on the main thread, so any custom implementations should make sure to background any expensive download operations.
 @result An opaque identifier to be used in canceling the download, via `cancelImageDownloadForIdentifier:`. You must
 retain the identifier if you wish to use it later.
 */
- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(nullable ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion;

/**
  @abstract Cancels an image download.
  @param downloadIdentifier The opaque download identifier object returned from 
      `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
  @discussion This method has no effect if `downloadIdentifier` is nil.
 */
- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier;

@optional

/**
 @abstract Cancels an image download, however indicating resume data should be stored in case of redownload.
 @param downloadIdentifier The opaque download identifier object returned from
 `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
 @discussion This method has no effect if `downloadIdentifier` is nil. If implemented, this method
 may be called instead of `cancelImageDownloadForIdentifier:` in cases where ASDK believes there's a chance
 the image download will be resumed (currently when an image exits preload range). You can use this to store
 any data that has already been downloaded for use in resuming the download later.
 */
- (void)cancelImageDownloadWithResumePossibilityForIdentifier:(id)downloadIdentifier;

/**
 @abstract Return an object that conforms to ASAnimatedImageProtocol
 @param animatedImageData Data that represents an animated image.
 */
- (nullable id <ASAnimatedImageProtocol>)animatedImageWithData:(NSData *)animatedImageData;


/**
 @abstract Sets block to be called when a progress image is available.
 @param progressBlock The block to be invoked when the download has a progressive render of an image available.
 @param callbackQueue The queue to call `progressBlock` on.
 @param downloadIdentifier The opaque download identifier object returned from
 `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
 */
- (void)setProgressImageBlock:(nullable ASImageDownloaderProgressImage)progressBlock
                callbackQueue:(dispatch_queue_t)callbackQueue
       withDownloadIdentifier:(id)downloadIdentifier;

/**
 @abstract Called to indicate what priority an image should be downloaded at.
 @param priority The priority at which the image should be downloaded.
 @param downloadIdentifier The opaque download identifier object returned from
 `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
 */
- (void)setPriority:(ASImageDownloaderPriority)priority
withDownloadIdentifier:(id)downloadIdentifier;

@end

@protocol ASAnimatedImageProtocol <NSObject>

@optional

/**
 @abstract A block which receives the cover image. Should be called when the objects cover image is ready.
 */
@property (nonatomic, strong, readwrite) void (^coverImageReadyCallback)(UIImage *coverImage);

/**
 @abstract Returns whether the supplied data contains a supported animated image format.
 @param data the data to check if contains a supported animated image.
 */
- (BOOL)isDataSupported:(NSData *)data;


@required

/**
 @abstract Return the objects's cover image.
 */
@property (nonatomic, readonly) UIImage *coverImage;
/**
 @abstract Return a boolean to indicate that the cover image is ready.
 */
@property (nonatomic, readonly) BOOL coverImageReady;
/**
 @abstract Return the total duration of the animated image's playback.
 */
@property (nonatomic, readonly) CFTimeInterval totalDuration;
/**
 @abstract Return the interval at which playback should occur. Will be set to a CADisplayLink's frame interval.
 */
@property (nonatomic, readonly) NSUInteger frameInterval;
/**
 @abstract Return the total number of loops the animated image should play or 0 to loop infinitely.
 */
@property (nonatomic, readonly) size_t loopCount;
/**
 @abstract Return the total number of frames in the animated image.
 */
@property (nonatomic, readonly) size_t frameCount;
/**
 @abstract Return YES when playback is ready to occur.
 */
@property (nonatomic, readonly) BOOL playbackReady;
/**
 @abstract Return any error that has occured. Playback will be paused if this returns non-nil.
 */
@property (nonatomic, readonly) NSError *error;
/**
 @abstract Should be called when playback is ready.
 */
@property (nonatomic, strong, readwrite) dispatch_block_t playbackReadyCallback;

/**
 @abstract Return the image at a given index.
 */
- (CGImageRef)imageAtIndex:(NSUInteger)index;
/**
 @abstract Return the duration at a given index.
 */
- (CFTimeInterval)durationAtIndex:(NSUInteger)index;
/**
 @abstract Clear any cached data. Called when playback is paused.
 */
- (void)clearAnimatedImageCache;

@end

NS_ASSUME_NONNULL_END
