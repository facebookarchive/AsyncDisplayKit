//
//  ASPINRemoteImageDownloader.m
//  Pods
//
//  Created by Garrett Moon on 2/5/16.
//
//

#ifdef PIN_REMOTE_IMAGE
#import "ASPINRemoteImageDownloader.h"

#import "ASAssert.h"
#import "ASThread.h"

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
  // We do not check the cache here and instead check it in downloadImageWithURL to avoid checking the cache twice.
  // If we're targeting the main queue and we're on the main thread, complete immediately.
  if (ASDisplayNodeThreadIsMain() && callbackQueue == dispatch_get_main_queue()) {
    completion(nil);
  } else {
    dispatch_async(callbackQueue, ^{
      completion(nil);
    });
  }
}

- (void)clearFetchedImageFromCacheWithURL:(NSURL *)URL
{
  PINRemoteImageManager *manager = [PINRemoteImageManager sharedImageManager];
  NSString *key = [manager cacheKeyForURL:URL processorKey:nil];
  [[[manager cache] memoryCache] removeObjectForKey:key];
}

- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(void (^)(CGFloat progress))downloadProgressBlock
                         completion:(void (^)(UIImage *image, NSError * error, id downloadIdentifier))completion
{
  return [[PINRemoteImageManager sharedImageManager] downloadImageWithURL:URL options:PINRemoteImageManagerDownloadOptionsSkipDecode completion:^(PINRemoteImageManagerResult *result) {
    /// If we're targeting the main queue and we're on the main thread, complete immediately.
    if (ASDisplayNodeThreadIsMain() && callbackQueue == dispatch_get_main_queue()) {
      completion(result.image, result.error, result.UUID);      
    } else {
      dispatch_async(callbackQueue, ^{
        completion(result.image, result.error, result.UUID);
      });
    }
  }];
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  [[PINRemoteImageManager sharedImageManager] cancelTaskWithUUID:downloadIdentifier];
}

- (void)setProgressImageBlock:(ASImageDownloaderProgressImage)progressBlock callbackQueue:(dispatch_queue_t)callbackQueue withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  if (progressBlock) {
    [[PINRemoteImageManager sharedImageManager] setProgressImageCallback:^(PINRemoteImageManagerResult * _Nonnull result) {
      dispatch_async(callbackQueue, ^{
        progressBlock(result.image, result.UUID);
      });
    } ofTaskWithUUID:downloadIdentifier];
  } else {
    [[PINRemoteImageManager sharedImageManager] setProgressImageCallback:nil ofTaskWithUUID:downloadIdentifier];
  }
}

- (void)setPriority:(ASImageDownloaderPriority)priority withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  PINRemoteImageManagerPriority pi_priority = PINRemoteImageManagerPriorityMedium;
  switch (priority) {
    case ASImageDownloaderPriorityPreload:
      pi_priority = PINRemoteImageManagerPriorityMedium;
      break;
      
    case ASImageDownloaderPriorityImminent:
      pi_priority = PINRemoteImageManagerPriorityHigh;
      break;
      
    case ASImageDownloaderPriorityVisible:
      pi_priority = PINRemoteImageManagerPriorityVeryHigh;
      break;
  }
  [[PINRemoteImageManager sharedImageManager] setPriority:pi_priority ofTaskWithUUID:downloadIdentifier];
}

@end
#endif