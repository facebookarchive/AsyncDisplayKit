//
//  ASPINRemoteImageDownloader.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#ifdef PIN_REMOTE_IMAGE
#import "ASPINRemoteImageDownloader.h"

#import "ASAssert.h"
#import "ASThread.h"
#import "ASImageContainerProtocolCategories.h"
#import "PINAnimatedImage.h"

#import <PINRemoteImage/PINAlternateRepresentationProvider.h>
#import <PINRemoteImage/PINRemoteImageManager.h>
#import <PINRemoteImage/NSData+ImageDetectors.h>
#import <PINCache/PINCache.h>

@interface ASPINRemoteImageDownloader () <PINRemoteImageManagerAlternateRepresentationProvider>

@end

@interface PINAnimatedImage (ASPINRemoteImageDownloader) <ASAnimatedImageProtocol>

@end

@implementation PINAnimatedImage (ASPINRemoteImageDownloader)

- (void)setCoverImageReadyCallback:(void (^)(UIImage * _Nonnull))coverImageReadyCallback
{
  self.infoCompletion = coverImageReadyCallback;
}

- (void (^)(UIImage * _Nonnull))coverImageReadyCallback
{
  return self.infoCompletion;
}

- (void)setPlaybackReadyCallback:(dispatch_block_t)playbackReadyCallback
{
  self.fileReady = playbackReadyCallback;
}

- (dispatch_block_t)playbackReadyCallback
{
  return self.fileReady;
}

@end

@implementation ASPINRemoteImageDownloader

+ (instancetype)sharedDownloader
{
  static ASPINRemoteImageDownloader *sharedDownloader = nil;
  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    sharedDownloader = [[ASPINRemoteImageDownloader alloc] init];
  });
  return sharedDownloader;
}

- (PINRemoteImageManager *)sharedPINRemoteImageManager
{
  static PINRemoteImageManager *sharedPINRemoteImageManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedPINRemoteImageManager = [[PINRemoteImageManager alloc] initWithSessionConfiguration:nil alternativeRepresentationProvider:self];
  });
  return sharedPINRemoteImageManager;
}

#pragma mark ASImageProtocols

- (nullable id <ASAnimatedImageProtocol>)animatedImageWithData:(NSData *)animatedImageData
{
  return [[PINAnimatedImage alloc] initWithAnimatedImageData:animatedImageData];
}

- (id <ASImageContainerProtocol>)synchronouslyFetchedCachedImageWithURL:(NSURL *)URL;
{
  NSString *key = [[self sharedPINRemoteImageManager] cacheKeyForURL:URL processorKey:nil];
  PINRemoteImageManagerResult *result = [[self sharedPINRemoteImageManager] synchronousImageFromCacheWithCacheKey:key options:PINRemoteImageManagerDownloadOptionsSkipDecode];
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
  PINRemoteImageManager *manager = [self sharedPINRemoteImageManager];
  NSString *key = [manager cacheKeyForURL:URL processorKey:nil];
  [[[manager cache] memoryCache] removeObjectForKey:key];
}

- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion;
{
  return [[self sharedPINRemoteImageManager] downloadImageWithURL:URL options:PINRemoteImageManagerDownloadOptionsSkipDecode completion:^(PINRemoteImageManagerResult *result) {
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
  [[self sharedPINRemoteImageManager] cancelTaskWithUUID:downloadIdentifier];
}

- (void)setProgressImageBlock:(ASImageDownloaderProgressImage)progressBlock callbackQueue:(dispatch_queue_t)callbackQueue withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  
  if (progressBlock) {
    [[self sharedPINRemoteImageManager] setProgressImageCallback:^(PINRemoteImageManagerResult * _Nonnull result) {
      dispatch_async(callbackQueue, ^{
        progressBlock(result.image, result.UUID);
      });
    } ofTaskWithUUID:downloadIdentifier];
  } else {
    [[self sharedPINRemoteImageManager] setProgressImageCallback:nil ofTaskWithUUID:downloadIdentifier];
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
  [[self sharedPINRemoteImageManager] setPriority:pi_priority ofTaskWithUUID:downloadIdentifier];
}

#pragma mark - PINRemoteImageManagerAlternateRepresentationProvider

- (id)alternateRepresentationWithData:(NSData *)data options:(PINRemoteImageManagerDownloadOptions)options
{
    if ([data pin_isGIF]) {
        return data;
    }
    return nil;
}

@end
#endif