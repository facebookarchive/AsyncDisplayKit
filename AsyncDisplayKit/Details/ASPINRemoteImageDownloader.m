//
//  ASPINRemoteImageDownloader.m
//  Pods
//
//  Created by Garrett Moon on 2/5/16.
//
//

#ifdef PIN_REMOTE_IMAGE
#import "ASPINRemoteImageDownloader.h"
#import <PINRemoteImage/PINRemoteImageManager.h>
#import <PINCache/PINCache.h>

@implementation ASPINRemoteImageDownloader

+ (instancetype)sharedDownloader
{
  static ASPINRemoteImageDownloader *sharedDownloader = nil;
  static dispatch_once_t once = 0;
  dispatch_once(&once, ^{
    sharedDownloader = [[ASPINRemoteImageDownloader alloc] init];
  });
  return sharedDownloader;
}

#pragma mark ASImageProtocols

- (void)fetchCachedImageWithURL:(NSURL *)URL
                  callbackQueue:(dispatch_queue_t)callbackQueue
                     completion:(void (^)(CGImageRef imageFromCache))completion
{
  NSString *key = [[PINRemoteImageManager sharedImageManager] cacheKeyForURL:URL processorKey:nil];
  UIImage *image = [[[[PINRemoteImageManager sharedImageManager] cache] memoryCache] objectForKey:key];
  
  dispatch_async(callbackQueue, ^{
    completion([image CGImage]);
  });
}

/**
 @abstract Downloads an image with the given URL.
 @param URL The URL of the image to download.
 @param callbackQueue The queue to call `downloadProgressBlock` and `completion` on. If this value is nil, both blocks
 will be invoked on the main-queue.
 @param downloadProgressBlock The block to be invoked when the download of `URL` progresses.
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
                   downloadProgress:(void (^)(CGFloat progress))downloadProgressBlock
                         completion:(void (^)(UIImage *image, NSError * error, id downloadIdentifier))completion
{
  return [[PINRemoteImageManager sharedImageManager] downloadImageWithURL:URL completion:^(PINRemoteImageManagerResult *result) {
    dispatch_async(callbackQueue, ^{
      completion(result.image, result.error, result.UUID);
    });
  }];
}

/**
 @abstract Cancels an image download.
 @param downloadIdentifier The opaque download identifier object returned from
 `downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:`.
 @discussion This method has no effect if `downloadIdentifier` is nil.
 */
- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  NSAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  [[PINRemoteImageManager sharedImageManager] cancelTaskWithUUID:downloadIdentifier];
}

- (void)setProgressImageBlock:(ASImageDownloaderProgressImage)progressBlock callbackQueue:(dispatch_queue_t)callbackQueue withDownloadIdentifier:(id)downloadIdentifier
{
  NSAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  [[PINRemoteImageManager sharedImageManager] setProgressCallback:^(PINRemoteImageManagerResult * _Nonnull result) {
    dispatch_async(callbackQueue, ^{
      progressBlock(result.image, result.UUID);
    });
  } ofTaskWithUUID:downloadIdentifier];
}

- (void)setPriority:(ASImageDownloaderPriority)priority withDownloadIdentifier:(id)downloadIdentifier
{
  NSAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  [[PINRemoteImageManager sharedImageManager] setPriority:PINRemoteImageManagerPriorityHigh ofTaskWithUUID:downloadIdentifier];
}

@end
#endif