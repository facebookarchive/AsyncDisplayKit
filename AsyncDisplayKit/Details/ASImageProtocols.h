/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ASImageCacherCompletion)(UIImage * _Nullable imageFromCache);

@protocol ASImageCacheProtocol <NSObject>

@optional

/**
 @abstract Attempts to fetch an image with the given URL from the cache.
 @param URL The URL of the image to retrieve from the cache.
 @param callbackQueue The queue to call `completion` on.
 @param completion The block to be called when the cache has either hit or missed.
 @param imageFromCache The image that was retrieved from the cache, if the image could be retrieved; nil otherwise.
 @discussion If `URL` is nil, `completion` will be invoked immediately with a nil image. This method should not block
 the calling thread as it is likely to be called from the main thread.
 */
- (void)cachedImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
                completion:(ASImageCacherCompletion)completion;

/**
 @abstract Called during clearFetchedData. Allows the cache to optionally trim items.
 @note Depending on your caches implementation you may *not* wish to respond to this method. It is however useful
 if you have a memory and disk cache in which case you'll likely want to clear out the memory cache.
 */
- (void)clearFetchedImageFromCacheWithURL:(NSURL *)URL;

@end

typedef void(^ASImageDownloaderCompletion)(UIImage  * _Nullable image, NSError * _Nullable error, id _Nullable downloadIdentifier);
typedef void(^ASImageDownloaderProgress)(CGFloat progress);
typedef void(^ASImageDownloaderProgressImage)(UIImage *progressImage, id _Nullable downloadIdentifier);

typedef NS_ENUM(NSUInteger, ASImageDownloaderPriority) {
  ASImageDownloaderPriorityPreload = 0,
  ASImageDownloaderPriorityImminent,
  ASImageDownloaderPriorityVisible
};

@protocol ASImageDownloaderProtocol <NSObject>

@required

/**
  @abstract Cancels an image download.
  @param downloadIdentifier The opaque download identifier object returned from 
      `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
  @discussion This method has no effect if `downloadIdentifier` is nil.
 */
- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier;

@optional

//You must implement the following method OR the deprecated method at the bottom

/**
 @abstract Downloads an image with the given URL.
 @param URL The URL of the image to download.
 @param callbackQueue The queue to call `downloadProgressBlock` and `completion` on.
 @param downloadProgress The block to be invoked when the download of `URL` progresses.
 @param progress The progress of the download, in the range of (0.0, 1.0), inclusive.
 @param completion The block to be invoked when the download has completed, or has failed.
 @param image The image that was downloaded, if the image could be successfully downloaded; nil otherwise.
 @param error An error describing why the download of `URL` failed, if the download failed; nil otherwise.
 @discussion This method is likely to be called on the main thread, so any custom implementations should make sure to background any expensive download operations.
 @result An opaque identifier to be used in canceling the download, via `cancelImageDownloadForIdentifier:`. You must
 retain the identifier if you wish to use it later.
 */
- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(nullable ASImageDownloaderProgress)downloadProgress
                         completion:(nullable ASImageDownloaderCompletion)completion;


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

@protocol ASImageDownloaderProtocolDeprecated <ASImageDownloaderProtocol>

@optional
/**
 @deprecated This method is deprecated @see downloadImageWithURL:callbackQueue:downloadProgress:completion: instead
 */
- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(nullable dispatch_queue_t)callbackQueue
              downloadProgressBlock:(void (^ _Nullable)(CGFloat progress))downloadProgressBlock
                         completion:(void (^ _Nullable)(CGImageRef _Nullable image, NSError * _Nullable error))completion;

@end

@protocol ASImageCacheProtocolDeprecated <ASImageCacheProtocol>

@optional
/**
 @deprecated This method is deprecated @see cachedImageWithURL:callbackQueue:completion: instead
 */
- (void)fetchCachedImageWithURL:(nullable NSURL *)URL
                  callbackQueue:(nullable dispatch_queue_t)callbackQueue
                     completion:(void (^)(CGImageRef _Nullable imageFromCache))completion;

@end

NS_ASSUME_NONNULL_END
