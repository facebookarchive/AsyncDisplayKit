//
//  ASPINRemoteImageDownloader.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if AS_PIN_REMOTE_IMAGE
#import <AsyncDisplayKit/ASPINRemoteImageDownloader.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASImageContainerProtocolCategories.h>

#if __has_include (<PINRemoteImage/PINAnimatedImage.h>)
#define PIN_ANIMATED_AVAILABLE 1
#import <PINRemoteImage/PINAnimatedImage.h>
#import <PINRemoteImage/PINAlternateRepresentationProvider.h>
#else
#define PIN_ANIMATED_AVAILABLE 0
#endif

#import <PINRemoteImage/PINRemoteImageManager.h>
#import <PINRemoteImage/NSData+ImageDetectors.h>
#import <PINRemoteImage/PINRemoteImageCaching.h>

#if PIN_ANIMATED_AVAILABLE

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

- (BOOL)isDataSupported:(NSData *)data
{
  return [data pin_isGIF];
}

@end
#endif

@interface ASPINRemoteImageManager : PINRemoteImageManager
@end

@implementation ASPINRemoteImageManager

//Share image cache with sharedImageManager image cache.
- (id <PINRemoteImageCaching>)defaultImageCache
{
  return [[PINRemoteImageManager sharedImageManager] cache];
}

@end


static ASPINRemoteImageDownloader *sharedDownloader = nil;

@interface ASPINRemoteImageDownloader ()
@end

@implementation ASPINRemoteImageDownloader

+ (instancetype)sharedDownloader
{

  static dispatch_once_t onceToken = 0;
  dispatch_once(&onceToken, ^{
    sharedDownloader = [[ASPINRemoteImageDownloader alloc] init];
  });
  return sharedDownloader;
}

+ (void)setSharedImageManagerWithConfiguration:(nullable NSURLSessionConfiguration *)configuration
{
  NSAssert(sharedDownloader == nil, @"Singleton has been created and session can no longer be configured.");
  __unused PINRemoteImageManager *sharedManager = [self sharedPINRemoteImageManagerWithConfiguration:configuration];
}

+ (PINRemoteImageManager *)sharedPINRemoteImageManagerWithConfiguration:(NSURLSessionConfiguration *)configuration
{
  static ASPINRemoteImageManager *sharedPINRemoteImageManager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{

#if PIN_ANIMATED_AVAILABLE
    // Check that Carthage users have linked both PINRemoteImage & PINCache by testing for one file each
    if (!(NSClassFromString(@"PINRemoteImageManager"))) {
      NSException *e = [NSException
                        exceptionWithName:@"FrameworkSetupException"
                        reason:@"Missing the path to the PINRemoteImage framework."
                        userInfo:nil];
      @throw e;
    }
    if (!(NSClassFromString(@"PINCache"))) {
      NSException *e = [NSException
                        exceptionWithName:@"FrameworkSetupException"
                        reason:@"Missing the path to the PINCache framework."
                        userInfo:nil];
      @throw e;
    }
    sharedPINRemoteImageManager = [[ASPINRemoteImageManager alloc] initWithSessionConfiguration:configuration
                                                              alternativeRepresentationProvider:[self sharedDownloader]];
#else
    sharedPINRemoteImageManager = [[ASPINRemoteImageManager alloc] initWithSessionConfiguration:configuration];
#endif
  });
  return sharedPINRemoteImageManager;
}

- (PINRemoteImageManager *)sharedPINRemoteImageManager
{
  return [ASPINRemoteImageDownloader sharedPINRemoteImageManagerWithConfiguration:nil];
}

- (BOOL)sharedImageManagerSupportsMemoryRemoval
{
  static BOOL sharedImageManagerSupportsMemoryRemoval = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedImageManagerSupportsMemoryRemoval = [[[self sharedPINRemoteImageManager] cache] respondsToSelector:@selector(removeObjectForKeyFromMemory:)];
  });
  return sharedImageManagerSupportsMemoryRemoval;
}

#pragma mark ASImageProtocols

#if PIN_ANIMATED_AVAILABLE
- (nullable id <ASAnimatedImageProtocol>)animatedImageWithData:(NSData *)animatedImageData
{
  return [[PINAnimatedImage alloc] initWithAnimatedImageData:animatedImageData];
}
#endif

- (id <ASImageContainerProtocol>)synchronouslyFetchedCachedImageWithURL:(NSURL *)URL;
{
  PINRemoteImageManager *manager = [self sharedPINRemoteImageManager];
  PINRemoteImageManagerResult *result = [manager synchronousImageFromCacheWithURL:URL processorKey:nil options:PINRemoteImageManagerDownloadOptionsSkipDecode];
  
#if PIN_ANIMATED_AVAILABLE
  if (result.alternativeRepresentation) {
    return result.alternativeRepresentation;
  }
#endif
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
  if ([self sharedImageManagerSupportsMemoryRemoval]) {
    PINRemoteImageManager *manager = [self sharedPINRemoteImageManager];
    NSString *key = [manager cacheKeyForURL:URL processorKey:nil];
    [[manager cache] removeObjectForKeyFromMemory:key];
  }
}

- (nullable id)downloadImageWithURL:(NSURL *)URL
                      callbackQueue:(dispatch_queue_t)callbackQueue
                   downloadProgress:(ASImageDownloaderProgress)downloadProgress
                         completion:(ASImageDownloaderCompletion)completion;
{
  return [[self sharedPINRemoteImageManager] downloadImageWithURL:URL options:PINRemoteImageManagerDownloadOptionsSkipDecode progressDownload:^(int64_t completedBytes, int64_t totalBytes) {
    if (downloadProgress == nil) { return; }

    /// If we're targeting the main queue and we're on the main thread, call immediately.
    if (ASDisplayNodeThreadIsMain() && callbackQueue == dispatch_get_main_queue()) {
      downloadProgress(completedBytes / (CGFloat)totalBytes);
    } else {
      dispatch_async(callbackQueue, ^{
        downloadProgress(completedBytes / (CGFloat)totalBytes);
      });
    }
  } completion:^(PINRemoteImageManagerResult * _Nonnull result) {
    /// If we're targeting the main queue and we're on the main thread, complete immediately.
    if (ASDisplayNodeThreadIsMain() && callbackQueue == dispatch_get_main_queue()) {
#if PIN_ANIMATED_AVAILABLE
      if (result.alternativeRepresentation) {
        completion(result.alternativeRepresentation, result.error, result.UUID);
      } else {
        completion(result.image, result.error, result.UUID);
      }
#else
      completion(result.image, result.error, result.UUID);
#endif
    } else {
      dispatch_async(callbackQueue, ^{
#if PIN_ANIMATED_AVAILABLE
        if (result.alternativeRepresentation) {
          completion(result.alternativeRepresentation, result.error, result.UUID);
        } else {
          completion(result.image, result.error, result.UUID);
        }
#else
        completion(result.image, result.error, result.UUID);
#endif
      });
    }
  }];
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  [[self sharedPINRemoteImageManager] cancelTaskWithUUID:downloadIdentifier storeResumeData:NO];
}

- (void)cancelImageDownloadWithResumePossibilityForIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");
  [[self sharedPINRemoteImageManager] cancelTaskWithUUID:downloadIdentifier storeResumeData:YES];
}

- (void)setProgressImageBlock:(ASImageDownloaderProgressImage)progressBlock callbackQueue:(dispatch_queue_t)callbackQueue withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");

  if (progressBlock) {
    [[self sharedPINRemoteImageManager] setProgressImageCallback:^(PINRemoteImageManagerResult * _Nonnull result) {
      dispatch_async(callbackQueue, ^{
        progressBlock(result.image, result.renderedImageQuality, result.UUID);
      });
    } ofTaskWithUUID:downloadIdentifier];
  } else {
    [[self sharedPINRemoteImageManager] setProgressImageCallback:nil ofTaskWithUUID:downloadIdentifier];
  }
}

- (void)setPriority:(ASImageDownloaderPriority)priority withDownloadIdentifier:(id)downloadIdentifier
{
  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:[NSUUID class]], @"downloadIdentifier must be NSUUID");

  PINRemoteImageManagerPriority pi_priority = PINRemoteImageManagerPriorityDefault;
  switch (priority) {
    case ASImageDownloaderPriorityPreload:
      pi_priority = PINRemoteImageManagerPriorityLow;
      break;

    case ASImageDownloaderPriorityImminent:
      pi_priority = PINRemoteImageManagerPriorityDefault;
      break;

    case ASImageDownloaderPriorityVisible:
      pi_priority = PINRemoteImageManagerPriorityHigh;
      break;
  }
  [[self sharedPINRemoteImageManager] setPriority:pi_priority ofTaskWithUUID:downloadIdentifier];
}

#pragma mark - PINRemoteImageManagerAlternateRepresentationProvider

- (id)alternateRepresentationWithData:(NSData *)data options:(PINRemoteImageManagerDownloadOptions)options
{
#if PIN_ANIMATED_AVAILABLE
  if ([data pin_isGIF]) {
    return data;
  }
#endif
  return nil;
}

@end
#endif
