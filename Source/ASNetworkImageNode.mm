//
//  ASNetworkImageNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASNetworkImageNode.h>

#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASBasicImageDownloader.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASImageNode+Private.h>
#import <AsyncDisplayKit/ASImageNode+AnimatedImagePrivate.h>
#import <AsyncDisplayKit/ASImageContainerProtocolCategories.h>

#if AS_PIN_REMOTE_IMAGE
#import <AsyncDisplayKit/ASPINRemoteImageDownloader.h>
#endif

static const CGSize kMinReleaseImageOnBackgroundSize = {20.0, 20.0};

@interface ASNetworkImageNode ()
{
  // Only access any of these with __instanceLock__.
  __weak id<ASNetworkImageNodeDelegate> _delegate;

  NSURL *_URL;
  UIImage *_defaultImage;

  NSUUID *_cacheUUID;
  id _downloadIdentifier;
  // The download identifier that we have set a progress block on, if any.
  id _downloadIdentifierForProgressBlock;

  BOOL _imageLoaded;
  BOOL _imageWasSetExternally;
  CGFloat _currentImageQuality;
  CGFloat _renderedImageQuality;
  BOOL _shouldRenderProgressImages;

  struct {
    unsigned int delegateDidStartFetchingData:1;
    unsigned int delegateDidFailWithError:1;
    unsigned int delegateDidFinishDecoding:1;
    unsigned int delegateDidLoadImage:1;
  } _delegateFlags;

  
  // Immutable and set on init only. We don't need to lock in this case.
  __weak id<ASImageDownloaderProtocol> _downloader;
  struct {
    unsigned int downloaderImplementsSetProgress:1;
    unsigned int downloaderImplementsSetPriority:1;
    unsigned int downloaderImplementsAnimatedImage:1;
    unsigned int downloaderImplementsCancelWithResume:1;
  } _downloaderFlags;

  // Immutable and set on init only. We don't need to lock in this case.
  __weak id<ASImageCacheProtocol> _cache;
  struct {
    unsigned int cacheSupportsClearing:1;
    unsigned int cacheSupportsSynchronousFetch:1;
  } _cacheFlags;
}

@end

@implementation ASNetworkImageNode

@dynamic image;

- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = (id<ASImageCacheProtocol>)cache;
  _downloader = (id<ASImageDownloaderProtocol>)downloader;
  
  _downloaderFlags.downloaderImplementsSetProgress = [downloader respondsToSelector:@selector(setProgressImageBlock:callbackQueue:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsSetPriority = [downloader respondsToSelector:@selector(setPriority:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsAnimatedImage = [downloader respondsToSelector:@selector(animatedImageWithData:)];
  _downloaderFlags.downloaderImplementsCancelWithResume = [downloader respondsToSelector:@selector(cancelImageDownloadWithResumePossibilityForIdentifier:)];

  _cacheFlags.cacheSupportsClearing = [cache respondsToSelector:@selector(clearFetchedImageFromCacheWithURL:)];
  _cacheFlags.cacheSupportsSynchronousFetch = [cache respondsToSelector:@selector(synchronouslyFetchedCachedImageWithURL:)];
  
  _shouldCacheImage = YES;
  _shouldRenderProgressImages = YES;
  self.shouldBypassEnsureDisplay = YES;

  return self;
}

- (instancetype)init
{
#if AS_PIN_REMOTE_IMAGE
  return [self initWithCache:[ASPINRemoteImageDownloader sharedDownloader] downloader:[ASPINRemoteImageDownloader sharedDownloader]];
#else
  return [self initWithCache:nil downloader:[ASBasicImageDownloader sharedImageDownloader]];
#endif
}

- (void)dealloc
{
  [self _cancelImageDownloadWithResumePossibility:NO];
}

#pragma mark - Public methods -- must lock

/// Setter for public image property. It has the side effect of setting an internal _imageWasSetExternally that prevents setting an image internally. Setting an image internally should happen with the _setImage: method
- (void)setImage:(UIImage *)image
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_setImage:image];
}

- (void)_locked_setImage:(UIImage *)image
{
  BOOL imageWasSetExternally = (image != nil);
  BOOL shouldCancelAndClear = imageWasSetExternally && (imageWasSetExternally != _imageWasSetExternally);
  _imageWasSetExternally = imageWasSetExternally;
  if (shouldCancelAndClear) {
    ASDisplayNodeAssertNil(_URL, @"Directly setting an image on an ASNetworkImageNode causes it to behave like an ASImageNode instead of an ASNetworkImageNode. If this is what you want, set the URL to nil first.");
    _URL = nil;
    [self _locked_cancelDownloadAndClearImageWithResumePossibility:NO];
  }
  
  [self _locked__setImage:image];
}

/// Setter for private image property. See @c _locked_setImage why this is needed
- (void)_setImage:(UIImage *)image
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked__setImage:image];
}

- (void)_locked__setImage:(UIImage *)image
{
  [super _locked_setImage:image];
}

- (void)setURL:(NSURL *)URL
{
  [self setURL:URL resetToDefault:YES];
}

- (void)setURL:(NSURL *)URL resetToDefault:(BOOL)reset
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    ASDisplayNodeAssert(_imageWasSetExternally == NO, @"Setting a URL to an ASNetworkImageNode after setting an image changes its behavior from an ASImageNode to an ASNetworkImageNode. If this is what you want, set the image to nil first.");
    
    _imageWasSetExternally = NO;
    
    if (ASObjectIsEqual(URL, _URL)) {
      return;
    }
    
    [self _locked_cancelImageDownloadWithResumePossibility:NO];

    _imageLoaded = NO;
    
    _URL = URL;
    
    BOOL hasURL = (_URL == nil);
    if (reset || hasURL) {
      [self _locked_setCurrentImageQuality:(hasURL ? 0.0 : 1.0)];
      [self _locked__setImage:_defaultImage];
    }
  }

  [self setNeedsPreload];
}

- (NSURL *)URL
{
  ASDN::MutexLocker l(__instanceLock__);
  return _URL;
}

- (void)setDefaultImage:(UIImage *)defaultImage
{
  ASDN::MutexLocker l(__instanceLock__);

  [self _locked_setDefaultImage:defaultImage];
}

- (void)_locked_setDefaultImage:(UIImage *)defaultImage
{
  if (ASObjectIsEqual(defaultImage, _defaultImage)) {
    return;
  }

  _defaultImage = defaultImage;

  if (!_imageLoaded) {
    [self _locked_setCurrentImageQuality:((_URL == nil) ? 0.0 : 1.0)];
    [self _locked__setImage:defaultImage];
    
  }
}

- (UIImage *)defaultImage
{
  ASDN::MutexLocker l(__instanceLock__);
  return _defaultImage;
}

- (void)setCurrentImageQuality:(CGFloat)currentImageQuality
{
  ASDN::MutexLocker l(__instanceLock__);
  _currentImageQuality = currentImageQuality;
}

- (CGFloat)currentImageQuality
{
  ASDN::MutexLocker l(__instanceLock__);
  return _currentImageQuality;
}

/**
 * Always use this methods internally to update the current image quality
 * We want to maintain the order that currentImageQuality is set regardless of the calling thread,
 * so we always have to dispatch to the main threadto ensure that we queue the operations in the correct order.
 * (see comment in displayDidFinish)
 */
- (void)_setCurrentImageQuality:(CGFloat)imageQuality
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_setCurrentImageQuality:imageQuality];
}

- (void)_locked_setCurrentImageQuality:(CGFloat)imageQuality
{
  dispatch_async(dispatch_get_main_queue(), ^{
    // As the setting of the image quality is dispatched the lock is gone by the time the block is executing.
    // Therefore we have to grab the lock again
    __instanceLock__.lock();
      _currentImageQuality = imageQuality;
    __instanceLock__.unlock();
  });
}

- (void)setRenderedImageQuality:(CGFloat)renderedImageQuality
{
  ASDN::MutexLocker l(__instanceLock__);
  _renderedImageQuality = renderedImageQuality;
}

- (CGFloat)renderedImageQuality
{
  ASDN::MutexLocker l(__instanceLock__);
  return _renderedImageQuality;
}

- (void)setDelegate:(id<ASNetworkImageNodeDelegate>)delegate
{
  ASDN::MutexLocker l(__instanceLock__);
  _delegate = delegate;
  
  _delegateFlags.delegateDidStartFetchingData = [delegate respondsToSelector:@selector(imageNodeDidStartFetchingData:)];
  _delegateFlags.delegateDidFailWithError = [delegate respondsToSelector:@selector(imageNode:didFailWithError:)];
  _delegateFlags.delegateDidFinishDecoding = [delegate respondsToSelector:@selector(imageNodeDidFinishDecoding:)];
  _delegateFlags.delegateDidLoadImage = [delegate respondsToSelector:@selector(imageNode:didLoadImage:)];
}

- (id<ASNetworkImageNodeDelegate>)delegate
{
  ASDN::MutexLocker l(__instanceLock__);
  return _delegate;
}

- (void)setShouldRenderProgressImages:(BOOL)shouldRenderProgressImages
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (shouldRenderProgressImages == _shouldRenderProgressImages) {
      return;
    }
    _shouldRenderProgressImages = shouldRenderProgressImages;
  }

  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (BOOL)shouldRenderProgressImages
{
  ASDN::MutexLocker l(__instanceLock__);
  return _shouldRenderProgressImages;
}

- (BOOL)placeholderShouldPersist
{
  ASDN::MutexLocker l(__instanceLock__);
  return (self.image == nil && _URL != nil);
}

/* displayWillStart in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  [super displayWillStartAsynchronously:asynchronously];
  
  if (asynchronously == NO && _cacheFlags.cacheSupportsSynchronousFetch) {
    ASDN::MutexLocker l(__instanceLock__);

    if (_imageLoaded == NO && _URL && _downloadIdentifier == nil) {
      UIImage *result = [[_cache synchronouslyFetchedCachedImageWithURL:_URL] asdk_image];
      if (result) {
        [self _locked_setCurrentImageQuality:1.0];
        [self _locked__setImage:result];
        
        _imageLoaded = YES;
      }
    }
  }

  // TODO: Consider removing this; it predates ASInterfaceState, which now ensures that even non-range-managed nodes get a -preload call.
  [self didEnterPreloadState];
  
  if (self.image == nil && _downloaderFlags.downloaderImplementsSetPriority) {
    __instanceLock__.lock();
      id downloadIdentifier = _downloadIdentifier;
    __instanceLock__.unlock();
    if (downloadIdentifier != nil) {
      [_downloader setPriority:ASImageDownloaderPriorityImminent withDownloadIdentifier:downloadIdentifier];
    }
  }
}

/* visibileStateDidChange in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  
  __instanceLock__.lock();
    id downloadIdentifier = nil;
    if (_downloaderFlags.downloaderImplementsSetPriority) {
      downloadIdentifier = _downloadIdentifier;
    }
  __instanceLock__.unlock();
  
  if (downloadIdentifier != nil) {
    [_downloader setPriority:ASImageDownloaderPriorityVisible withDownloadIdentifier:downloadIdentifier];
  }
  
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];

  __instanceLock__.lock();
    id downloadIdentifier = nil;
    if (_downloaderFlags.downloaderImplementsSetPriority) {
      downloadIdentifier = _downloadIdentifier;
    }
  __instanceLock__.unlock();
  
  if (downloadIdentifier != nil) {
    [_downloader setPriority:ASImageDownloaderPriorityPreload withDownloadIdentifier:downloadIdentifier];
  }
  
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)didExitPreloadState
{
  [super didExitPreloadState];

  __instanceLock__.lock();
    BOOL imageWasSetExternally = _imageWasSetExternally;
  __instanceLock__.unlock();
  // If the image was set explicitly we don't want to remove it while exiting the preload state
  if (imageWasSetExternally) {
    return;
  }

  [self _cancelDownloadAndClearImageWithResumePossibility:YES];
}

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  // Image was set externally no need to load an image
  [self _lazilyLoadImageIfNecessary];
}

#pragma mark - Progress

- (void)handleProgressImage:(UIImage *)progressImage progress:(CGFloat)progress downloadIdentifier:(nullable id)downloadIdentifier
{
  __instanceLock__.lock();
  
  // Getting a result back for a different download identifier, download must not have been successfully canceled
  if (ASObjectIsEqual(_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
    return;
  }
  
  [self _locked_setCurrentImageQuality:progress];
  [self _locked__setImage:progressImage];

  __instanceLock__.unlock();
}

- (void)_updateProgressImageBlockOnDownloaderIfNeeded
{
  // If the downloader doesn't do progress, we are done.
  if (_downloaderFlags.downloaderImplementsSetProgress == NO) {
    return;
  }

  // Read state.
  __instanceLock__.lock();
    BOOL shouldRender = _shouldRenderProgressImages && ASInterfaceStateIncludesVisible(_interfaceState);
    id oldDownloadIDForProgressBlock = _downloadIdentifierForProgressBlock;
    id newDownloadIDForProgressBlock = shouldRender ? _downloadIdentifier : nil;
    BOOL clearAndReattempt = NO;
  __instanceLock__.unlock();

  // If we're already bound to the correct download, we're done.
  if (ASObjectIsEqual(oldDownloadIDForProgressBlock, newDownloadIDForProgressBlock)) {
    return;
  }

  // Unbind from the previous download.
  if (oldDownloadIDForProgressBlock != nil) {
    [_downloader setProgressImageBlock:nil callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:oldDownloadIDForProgressBlock];
  }

  // Bind to the current download.
  if (newDownloadIDForProgressBlock != nil) {
    __weak __typeof(self) weakSelf = self;
    [_downloader setProgressImageBlock:^(UIImage * _Nonnull progressImage, CGFloat progress, id  _Nullable downloadIdentifier) {
      [weakSelf handleProgressImage:progressImage progress:progress downloadIdentifier:downloadIdentifier];
    } callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:newDownloadIDForProgressBlock];
  }

  // Update state local state with lock held.
  {
    ASDN::MutexLocker l(__instanceLock__);
    // Check if the oldDownloadIDForProgressBlock still is the same as the _downloadIdentifierForProgressBlock
    if (_downloadIdentifierForProgressBlock == oldDownloadIDForProgressBlock) {
      _downloadIdentifierForProgressBlock = newDownloadIDForProgressBlock;
    } else if (newDownloadIDForProgressBlock != nil) {
      // If this is not the case another thread did change the _downloadIdentifierForProgressBlock already so
      // we have to deregister the newDownloadIDForProgressBlock that we registered above
      clearAndReattempt = YES;
    }
  }
  
  if (clearAndReattempt) {
    // In this case another thread changed the _downloadIdentifierForProgressBlock before we finished registering
    // the new progress block for newDownloadIDForProgressBlock ID. Let's clear it now and reattempt to register
    if (newDownloadIDForProgressBlock) {
      [_downloader setProgressImageBlock:nil callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:newDownloadIDForProgressBlock];
    }
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
  }
}

- (void)_cancelDownloadAndClearImageWithResumePossibility:(BOOL)storeResume
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_cancelDownloadAndClearImageWithResumePossibility:storeResume];
}

- (void)_locked_cancelDownloadAndClearImageWithResumePossibility:(BOOL)storeResume
{
  [self _locked_cancelImageDownloadWithResumePossibility:storeResume];
  
  // Destruction of bigger images on the main thread can be expensive
  // and can take some time, so we dispatch onto a bg queue to
  // actually dealloc.
  UIImage *image = [self _locked_Image];
  UIImage *defaultImage = _defaultImage;
  CGSize imageSize = image.size;
  BOOL shouldReleaseImageOnBackgroundThread = imageSize.width > kMinReleaseImageOnBackgroundSize.width ||
                                              imageSize.height > kMinReleaseImageOnBackgroundSize.height;
  if (shouldReleaseImageOnBackgroundThread) {
    ASPerformBackgroundDeallocation(image);
  }

  [self _locked_setAnimatedImage:nil];
  [self _locked_setCurrentImageQuality:0.0];
  [self _locked__setImage:defaultImage];

  _imageLoaded = NO;

  if (_cacheFlags.cacheSupportsClearing) {
    if (_URL != nil) {
      [_cache clearFetchedImageFromCacheWithURL:_URL];
    }
  }
}

- (void)_cancelImageDownloadWithResumePossibility:(BOOL)storeResume
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_cancelImageDownloadWithResumePossibility:storeResume];
}

- (void)_locked_cancelImageDownloadWithResumePossibility:(BOOL)storeResume
{
  if (!_downloadIdentifier) {
    return;
  }

  if (_downloadIdentifier) {
    if (storeResume && _downloaderFlags.downloaderImplementsCancelWithResume) {
      [_downloader cancelImageDownloadWithResumePossibilityForIdentifier:_downloadIdentifier];
    } else {
      [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
    }
  }
  _downloadIdentifier = nil;

  _cacheUUID = nil;
}

- (void)_downloadImageWithCompletion:(void (^)(id <ASImageContainerProtocol> imageContainer, NSError*, id downloadIdentifier))finished
{
  ASPerformBlockOnBackgroundThread(^{
    NSURL *url;
    id downloadIdentifier;
    BOOL cancelAndReattempt = NO;
    
    // Below, to avoid performance issues, we're calling downloadImageWithURL without holding the lock. This is a bit ugly because
    // We need to reobtain the lock after and ensure that the task we've kicked off still matches our URL. If not, we need to cancel
    // it and try again.
    {
      ASDN::MutexLocker l(__instanceLock__);
      url = _URL;
    }
    
    downloadIdentifier = [_downloader downloadImageWithURL:url
                                             callbackQueue:dispatch_get_main_queue()
                                          downloadProgress:NULL
                                                completion:^(id <ASImageContainerProtocol> _Nullable imageContainer, NSError * _Nullable error, id  _Nullable downloadIdentifier) {
                                                  if (finished != NULL) {
                                                    finished(imageContainer, error, downloadIdentifier);
                                                  }
                                                }];
  
    {
      ASDN::MutexLocker l(__instanceLock__);
      if (ASObjectIsEqual(_URL, url)) {
        // The download we kicked off is correct, no need to do any more work.
        _downloadIdentifier = downloadIdentifier;
      } else {
        // The URL changed since we kicked off our download task. This shouldn't happen often so we'll pay the cost and
        // cancel that request and kick off a new one.
        cancelAndReattempt = YES;
      }
    }
    
    if (cancelAndReattempt) {
      if (downloadIdentifier != nil) {
        [_downloader cancelImageDownloadForIdentifier:downloadIdentifier];
      }
      [self _downloadImageWithCompletion:finished];
      return;
    }
    
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
  });
}

- (void)_lazilyLoadImageIfNecessary
{
  __instanceLock__.lock();
    __weak id<ASNetworkImageNodeDelegate> delegate = _delegate;
    BOOL delegateDidStartFetchingData = _delegateFlags.delegateDidStartFetchingData;
    BOOL isImageLoaded = _imageLoaded;
    NSURL *URL = _URL;
    id currentDownloadIdentifier = _downloadIdentifier;
  __instanceLock__.unlock();
  
  if (!isImageLoaded && URL != nil && currentDownloadIdentifier == nil) {
    if (delegateDidStartFetchingData) {
      [delegate imageNodeDidStartFetchingData:self];
    }
    
    if (URL.isFileURL) {
      dispatch_async(dispatch_get_main_queue(), ^{
        ASDN::MutexLocker l(__instanceLock__);
        
        // Bail out if not the same URL anymore
        if (!ASObjectIsEqual(URL, _URL)) {
          return;
        }
        
        if (_shouldCacheImage) {
          [self _locked__setImage:[UIImage imageNamed:_URL.path.lastPathComponent]];
        } else {
          // First try to load the path directly, for efficiency assuming a developer who
          // doesn't want caching is trying to be as minimal as possible.
          UIImage *nonAnimatedImage = [UIImage imageWithContentsOfFile:_URL.path];
          if (nonAnimatedImage == nil) {
            // If we couldn't find it, execute an -imageNamed:-like search so we can find resources even if the
            // extension is not provided in the path.  This allows the same path to work regardless of shouldCacheImage.
            NSString *filename = [[NSBundle mainBundle] pathForResource:_URL.path.lastPathComponent ofType:nil];
            if (filename != nil) {
              nonAnimatedImage = [UIImage imageWithContentsOfFile:filename];
            }
          }

          // If the file may be an animated gif and then created an animated image.
          id<ASAnimatedImageProtocol> animatedImage = nil;
          if (_downloaderFlags.downloaderImplementsAnimatedImage) {
            NSData *data = [NSData dataWithContentsOfURL:_URL];
            if (data != nil) {
              animatedImage = [_downloader animatedImageWithData:data];

              if ([animatedImage respondsToSelector:@selector(isDataSupported:)] && [animatedImage isDataSupported:data] == NO) {
                animatedImage = nil;
              }
            }
          }

          if (animatedImage != nil) {
            [self _locked_setAnimatedImage:animatedImage];
          } else {
            [self _locked__setImage:nonAnimatedImage];
          }
        }

        _imageLoaded = YES;

        [self _locked_setCurrentImageQuality:1.0];

        if (_delegateFlags.delegateDidLoadImage) {
          ASDN::MutexUnlocker u(__instanceLock__);
          [delegate imageNode:self didLoadImage:self.image];
        }
      });
    } else {
      __weak __typeof__(self) weakSelf = self;
      void (^finished)(id <ASImageContainerProtocol>, NSError *, id downloadIdentifier) = ^(id <ASImageContainerProtocol>imageContainer, NSError *error, id downloadIdentifier) {
       
        __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
          return;
        }

        // Grab the lock for the rest of the block
        ASDN::MutexLocker l(strongSelf->__instanceLock__);
        
        //Getting a result back for a different download identifier, download must not have been successfully canceled
        if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
            return;
        }

        if (imageContainer != nil) {
          [strongSelf _locked_setCurrentImageQuality:1.0];
          if ([imageContainer asdk_animatedImageData] && strongSelf->_downloaderFlags.downloaderImplementsAnimatedImage) {
            id animatedImage = [strongSelf->_downloader animatedImageWithData:[imageContainer asdk_animatedImageData]];
            [strongSelf _locked_setAnimatedImage:animatedImage];
          } else {
            [strongSelf _locked__setImage:[imageContainer asdk_image]];
          }
          strongSelf->_imageLoaded = YES;
        }

        strongSelf->_downloadIdentifier = nil;
        strongSelf->_cacheUUID = nil;

        if (imageContainer != nil) {
          if (strongSelf->_delegateFlags.delegateDidLoadImage) {
            ASDN::MutexUnlocker u(strongSelf->__instanceLock__);
            [delegate imageNode:strongSelf didLoadImage:strongSelf.image];
          }
        } else if (error && strongSelf->_delegateFlags.delegateDidFailWithError) {
          ASDN::MutexUnlocker u(strongSelf->__instanceLock__);
          [delegate imageNode:strongSelf didFailWithError:error];
        }
      };

      // As the _cache and _downloader is only set once in the intializer we don't have to use a
      // lock in here
      if (_cache != nil) {
        NSUUID *cacheUUID = [NSUUID UUID];
        __instanceLock__.lock();
          _cacheUUID = cacheUUID;
        __instanceLock__.unlock();

        [_cache cachedImageWithURL:URL
                     callbackQueue:dispatch_get_main_queue()
                        completion:^(id <ASImageContainerProtocol> imageContainer) {
                          // If the cache UUID changed, that means this request was cancelled.
                          __instanceLock__.lock();
                            NSUUID *currentCacheUUID = _cacheUUID;
                          __instanceLock__.unlock();
                            
                          if (!ASObjectIsEqual(currentCacheUUID, cacheUUID)) {
                            return;
                          }
  
                          if ([imageContainer asdk_image] == nil && _downloader != nil) {
                            [self _downloadImageWithCompletion:finished];
                          } else {
                            finished(imageContainer, nil, nil);
                          }
                        }];
      } else {
        [self _downloadImageWithCompletion:finished];
      }
    }
  }
}

#pragma mark - ASDisplayNode+Subclasses

- (void)displayDidFinish
{
  [super displayDidFinish];
  
  id<ASNetworkImageNodeDelegate> delegate = nil;
  
  __instanceLock__.lock();
    if (_delegateFlags.delegateDidFinishDecoding && self.layer.contents != nil) {
      /* We store the image quality in _currentImageQuality whenever _image is set. On the following displayDidFinish, we'll know that
       _currentImageQuality is the quality of the image that has just finished rendering. In order for this to be accurate, we
       need to be sure we are on main thread when we set _currentImageQuality. Otherwise, it is possible for _currentImageQuality
       to be modified at a point where it is too late to cancel the main thread's previous display (the final sentinel check has passed), 
       but before the displayDidFinish of the previous display pass is called. In this situation, displayDidFinish would be called and we
       would set _renderedImageQuality to the new _currentImageQuality, but the actual quality of the rendered image should be the previous 
       value stored in _currentImageQuality. */

      _renderedImageQuality = _currentImageQuality;
      
      // Assign the delegate to be used
      delegate = _delegate;
    }
  
  __instanceLock__.unlock();
  
  if (delegate != nil) {
    [delegate imageNodeDidFinishDecoding:self];
  }
}

@end
