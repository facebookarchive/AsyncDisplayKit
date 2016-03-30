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

#import <PINRemoteImage/PINAlternateRepresentationDelegate.h>
#import <PINRemoteImage/PINRemoteImageManager.h>
#import <PINRemoteImage/NSData+ImageDetectors.h>
#import <PINCache/PINCache.h>

@interface ASPINRemoteImageDownloader () <PINRemoteImageManagerAlternateRepresentationDelegate>

@end

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

+ (PINRemoteImageManager *)sharedPINRemoteImageManager
{
    static PINRemoteImageManager *sharedPINRemoteImageManager = nil;
    static dispatch_once_t once = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPINRemoteImageManager = [[PINRemoteImageManager alloc] initWithSessionConfiguration:nil alternativeRepresentationDelegate:self];
    });
    return sharedPINRemoteImageManager;
}

- (id <ASImageContainerProtocol>)synchronouslyFetchedCachedImageWithURL:(NSURL *)URL;
{
  NSString *key = [[[self class] sharedPINRemoteImageManager] cacheKeyForURL:URL processorKey:nil];
  PINRemoteImageManagerResult *result = [[[self class] sharedPINRemoteImageManager] synchronousImageFromCacheWithCacheKey:key options:PINRemoteImageManagerDownloadOptionsSkipDecode];
  if (result.alternativeRepresentation) {
    return result.alternativeRepresentation;
  }
  return result.image;
}

- (void)cachedImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
                completion:(ASImageCacherCompletion)completion
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
  PINRemoteImageManager *manager = [[self class] sharedPINRemoteImageManager];
  NSString *key = [manager cacheKeyForURL:URL processorKey:nil];
  [[[manager cache] memoryCache] removeObjectForKey:key];
}

- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion;
{
  return [[[self class] sharedPINRemoteImageManager] downloadImageWithURL:URL options:PINRemoteImageManagerDownloadOptionsSkipDecode completion:^(PINRemoteImageManagerResult *result) {
    /// If we're targeting the main queue and we're on the main thread, complete immediately.
    if (ASDisplayNodeThreadIsMain() && callbackQueue == dispatch_get_main_queue()) {
      if (result.alternativeRepresentation) {
        completion(result.alternativeRepresentation, result.error, result.UUID);
      } else {
        completion(result.image, result.error, result.UUID);
      }
    } else {
      dispatch_async(callbackQueue, ^{
        if (result.alternativeRepresentation) {
          completion(result.alternativeRepresentation, result.error, result.UUID);
        } else {
          completion(result.image, result.error, result.UUID);
        }
      });
    }
  }];
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  [[[self class] sharedPINRemoteImageManager] cancelTaskWithUUID:downloadIdentifier];
}

- (void)setProgressImageBlock:(ASImageDownloaderProgressImage)progressBlock callbackQueue:(dispatch_queue_t)callbackQueue withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  if (progressBlock) {
    [[[self class] sharedPINRemoteImageManager] setProgressImageCallback:^(PINRemoteImageManagerResult * _Nonnull result) {
      dispatch_async(callbackQueue, ^{
        progressBlock(result.image, result.UUID);
      });
    } ofTaskWithUUID:downloadIdentifier];
  } else {
    [[[self class] sharedPINRemoteImageManager] setProgressImageCallback:nil ofTaskWithUUID:downloadIdentifier];
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
  [[[self class] sharedPINRemoteImageManager] setPriority:pi_priority ofTaskWithUUID:downloadIdentifier];
}

#pragma mark - PINRemoteImageManagerAlternateRepresentationDelegate

+ (id)alternateRepresentationWithData:(NSData *)data options:(PINRemoteImageManagerDownloadOptions)options
{
    if ([data pin_isGIF]) {
        return data;
    }
    return nil;
}

@end
#endif