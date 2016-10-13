//
//  ASNetworkImageNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASNetworkImageNode.h"

#import "ASBasicImageDownloader.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASEqualityHelpers.h"
#import "ASInternalHelpers.h"
#import "ASImageContainerProtocolCategories.h"
#import "ASDisplayNodeExtras.h"

#if PIN_REMOTE_IMAGE
#import "ASPINRemoteImageDownloader.h"
#endif

static const CGSize kMinReleaseImageOnBackgroundSize = {20.0, 20.0};

@interface ASNetworkImageNode ()
{
  __weak id<ASImageCacheProtocol> _cache;
  __weak id<ASImageDownloaderProtocol> _downloader;

  // Only access any of these with __instanceLock__.
  __weak id<ASNetworkImageNodeDelegate> _delegate;

  NSURL *_URL;
  UIImage *_defaultImage;

  NSUUID *_cacheUUID;
  id _downloadIdentifier;

  BOOL _imageLoaded;
  CGFloat _currentImageQuality;
  CGFloat _renderedImageQuality;
  BOOL _shouldRenderProgressImages;

  struct {
    unsigned int delegateDidStartFetchingData:1;
    unsigned int delegateDidFailWithError:1;
    unsigned int delegateDidFinishDecoding:1;
    unsigned int delegateDidLoadImage:1;
  } _delegateFlags;

  //set on init only
  struct {
    unsigned int downloaderSupportsNewProtocol:1;
    unsigned int downloaderImplementsSetProgress:1;
    unsigned int downloaderImplementsSetPriority:1;
    unsigned int downloaderImplementsAnimatedImage:1;
  } _downloaderFlags;

  struct {
    unsigned int cacheSupportsCachedImage:1;
    unsigned int cacheSupportsClearing:1;
    unsigned int cacheSupportsSynchronousFetch:1;
  } _cacheFlags;
}
@end

@implementation ASNetworkImageNode

- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = (id<ASImageCacheProtocol>)cache;
  _downloader = (id<ASImageDownloaderProtocol>)downloader;
  
  ASDisplayNodeAssert([downloader respondsToSelector:@selector(downloadImageWithURL:callbackQueue:downloadProgress:completion:)], @"downloader must respond to either downloadImageWithURL:callbackQueue:downloadProgress:completion:.");
  
  _downloaderFlags.downloaderSupportsNewProtocol = [downloader respondsToSelector:@selector(downloadImageWithURL:callbackQueue:downloadProgress:completion:)];
  
  ASDisplayNodeAssert(cache == nil || [cache respondsToSelector:@selector(cachedImageWithURL:callbackQueue:completion:)], @"cacher must respond to either cachedImageWithURL:callbackQueue:completion:");
  
  _downloaderFlags.downloaderImplementsSetProgress = [downloader respondsToSelector:@selector(setProgressImageBlock:callbackQueue:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsSetPriority = [downloader respondsToSelector:@selector(setPriority:withDownloadIdentifier:)];
  _downloaderFlags.downloaderImplementsAnimatedImage = [downloader respondsToSelector:@selector(animatedImageWithData:)];
  
  _cacheFlags.cacheSupportsCachedImage = [cache respondsToSelector:@selector(cachedImageWithURL:callbackQueue:completion:)];
  _cacheFlags.cacheSupportsClearing = [cache respondsToSelector:@selector(clearFetchedImageFromCacheWithURL:)];
  _cacheFlags.cacheSupportsSynchronousFetch = [cache respondsToSelector:@selector(synchronouslyFetchedCachedImageWithURL:)];
  
  _shouldCacheImage = YES;
  _shouldRenderProgressImages = YES;
  self.shouldBypassEnsureDisplay = YES;

  return self;
}

- (instancetype)init
{
#if PIN_REMOTE_IMAGE
  return [self initWithCache:[ASPINRemoteImageDownloader sharedDownloader] downloader:[ASPINRemoteImageDownloader sharedDownloader]];
#else
  return [self initWithCache:nil downloader:[ASBasicImageDownloader sharedImageDownloader]];
#endif
}

- (void)dealloc
{
  [self _cancelImageDownload];
}

#pragma mark - Public methods -- must lock

- (void)setURL:(NSURL *)URL
{
  [self setURL:URL resetToDefault:YES];
}

- (void)setURL:(NSURL *)URL resetToDefault:(BOOL)reset
{
  ASDN::MutexLocker l(__instanceLock__);

  if (ASObjectIsEqual(URL, _URL)) {
    return;
  }

  [self _cancelImageDownload];
  _imageLoaded = NO;

  _URL = URL;

  BOOL hasURL = _URL == nil;
  if (reset || hasURL) {
    self.image = _defaultImage;
    /* We want to maintain the order that currentImageQuality is set regardless of the calling thread,
     so always use a dispatch_async to ensure that we queue the operations in the correct order.
     (see comment in displayDidFinish) */
    dispatch_async(dispatch_get_main_queue(), ^{
      self.currentImageQuality = hasURL ? 0.0 : 1.0;
    });
  }

  [self setNeedsDataFetch];
}

- (NSURL *)URL
{
  ASDN::MutexLocker l(__instanceLock__);
  return _URL;
}

- (void)setDefaultImage:(UIImage *)defaultImage
{
  ASDN::MutexLocker l(__instanceLock__);

  if (ASObjectIsEqual(defaultImage, _defaultImage)) {
    return;
  }
  _defaultImage = defaultImage;

  if (!_imageLoaded) {
    BOOL hasURL = _URL == nil;
    /* We want to maintain the order that currentImageQuality is set regardless of the calling thread,
     so always use a dispatch_async to ensure that we queue the operations in the correct order.
     (see comment in displayDidFinish) */
    dispatch_async(dispatch_get_main_queue(), ^{
      self.currentImageQuality = hasURL ? 0.0 : 1.0;
    });
    self.image = defaultImage;
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
  __instanceLock__.lock();
  if (shouldRenderProgressImages == _shouldRenderProgressImages) {
    __instanceLock__.unlock();
    return;
  }
  
  _shouldRenderProgressImages = shouldRenderProgressImages;
  
  
  __instanceLock__.unlock();
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
        self.image = result;
        _imageLoaded = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          _currentImageQuality = 1.0;
        });
      }
    }
  }

  // TODO: Consider removing this; it predates ASInterfaceState, which now ensures that even non-range-managed nodes get a -fetchData call.
  [self fetchData];
  
  if (self.image == nil && _downloaderFlags.downloaderImplementsSetPriority) {
    ASDN::MutexLocker l(__instanceLock__);
    if (_downloadIdentifier != nil) {
      [_downloader setPriority:ASImageDownloaderPriorityImminent withDownloadIdentifier:_downloadIdentifier];
    }
  }
}

/* visibileStateDidChange in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)didEnterVisibleState
{
  [super didEnterVisibleState];
  
  if (_downloaderFlags.downloaderImplementsSetPriority) {
    ASDN::MutexLocker l(__instanceLock__);
    if (_downloadIdentifier != nil) {
      [_downloader setPriority:ASImageDownloaderPriorityVisible withDownloadIdentifier:_downloadIdentifier];
    }
  }
  
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)didExitVisibleState
{
  [super didExitVisibleState];
  
  if (_downloaderFlags.downloaderImplementsSetPriority) {
    ASDN::MutexLocker l(__instanceLock__);
    if (_downloadIdentifier != nil) {
      [_downloader setPriority:ASImageDownloaderPriorityPreload withDownloadIdentifier:_downloadIdentifier];
    }
  }
  
  [self _updateProgressImageBlockOnDownloaderIfNeeded];
}

- (void)clearFetchedData
{
  [super clearFetchedData];

  {
    ASDN::MutexLocker l(__instanceLock__);

    [self _cancelImageDownload];
    [self _clearImage];
    if (_cacheFlags.cacheSupportsClearing) {
      [_cache clearFetchedImageFromCacheWithURL:_URL];
    }
  }
}

- (void)fetchData
{
  [super fetchData];
  
  {
    ASDN::MutexLocker l(__instanceLock__);
    [self _lazilyLoadImageIfNecessary];
  }
}

#pragma mark - Layout and Sizing

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDN::MutexLocker l(__instanceLock__);

  // If the image node is currently in the loading process and no valid size is applied return CGSizeZero for the time
  // being.
  // TODO: After 2.0 is stable we should remove this behavior as a ASNetworkImageNode is a replaced element and the
  // client code should set the size of an image or it's container it's embedded in
  if (ASIsCGSizeValidForSize(constrainedSize) == NO && _URL != nil && self.image == nil) {
    return CGSizeZero;
  }
    
  return [super calculateSizeThatFits:constrainedSize];
}

#pragma mark - Private methods -- only call with lock.

- (void)_updateProgressImageBlockOnDownloaderIfNeeded
{
  ASDN::MutexLocker l(__instanceLock__);
  
  BOOL shouldRenderProgressImages = _shouldRenderProgressImages;
  ASInterfaceState interfaceState = self.interfaceState;

  if (!_downloaderFlags.downloaderImplementsSetProgress || _downloadIdentifier == nil) {
    return;
  }

  ASImageDownloaderProgressImage progress = nil;
  if (shouldRenderProgressImages && ASInterfaceStateIncludesVisible(interfaceState)) {
    __weak __typeof__(self) weakSelf = self;
    progress = ^(UIImage * _Nonnull progressImage, CGFloat progress, id _Nullable downloadIdentifier) {
      __typeof__(self) strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }

      ASDN::MutexLocker l(strongSelf->__instanceLock__);
      //Getting a result back for a different download identifier, download must not have been successfully canceled
      if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
        return;
      }
      strongSelf.image = progressImage;
      dispatch_async(dispatch_get_main_queue(), ^{
        // See comment in -displayDidFinish for why this must be dispatched to main
        strongSelf.currentImageQuality = progress;
      });
    };
  }
  [_downloader setProgressImageBlock:progress callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:_downloadIdentifier];
}

- (void)_clearImage
{
  // Destruction of bigger images on the main thread can be expensive
  // and can take some time, so we dispatch onto a bg queue to
  // actually dealloc.
  __block UIImage *image = self.image;
  CGSize imageSize = image.size;
  BOOL shouldReleaseImageOnBackgroundThread = imageSize.width > kMinReleaseImageOnBackgroundSize.width ||
                                              imageSize.height > kMinReleaseImageOnBackgroundSize.height;
  if (shouldReleaseImageOnBackgroundThread) {
    ASPerformBlockOnDeallocationQueue(^{
      image = nil;
    });
  }
  self.animatedImage = nil;
  self.image = _defaultImage;
  _imageLoaded = NO;
  // See comment in -displayDidFinish for why this must be dispatched to main
  dispatch_async(dispatch_get_main_queue(), ^{
    self.currentImageQuality = 0.0;
  });
}

- (void)_cancelImageDownload
{
  if (!_downloadIdentifier) {
    return;
  }

  if (_downloadIdentifier) {
    [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
  }
  _downloadIdentifier = nil;

  _cacheUUID = nil;
}

- (void)_downloadImageWithCompletion:(void (^)(id <ASImageContainerProtocol> imageContainer, NSError*, id downloadIdentifier))finished
{
  ASPerformBlockOnBackgroundThread(^{
    
    ASDN::MutexLocker l(__instanceLock__);
    if (_downloaderFlags.downloaderSupportsNewProtocol) {
      _downloadIdentifier = [_downloader downloadImageWithURL:_URL
                                                callbackQueue:dispatch_get_main_queue()
                                             downloadProgress:NULL
                                                   completion:^(id <ASImageContainerProtocol> _Nullable imageContainer, NSError * _Nullable error, id  _Nullable downloadIdentifier) {
                                                     if (finished != NULL) {
                                                       finished(imageContainer, error, downloadIdentifier);
                                                     }
                                                   }];
    }
  
    [self _updateProgressImageBlockOnDownloaderIfNeeded];
      
  });
}

- (void)_lazilyLoadImageIfNecessary
{
  // FIXME: We should revisit locking in this method (e.g. to access the instance variables at the top, and holding lock while calling delegate)
  if (!_imageLoaded && _URL != nil && _downloadIdentifier == nil) {
    {
      ASDN::MutexLocker l(__instanceLock__);
      if (_delegateFlags.delegateDidStartFetchingData) {
        [_delegate imageNodeDidStartFetchingData:self];
      }
    }
    
    if (_URL.isFileURL) {
      {
        ASDN::MutexLocker l(__instanceLock__);

        dispatch_async(dispatch_get_main_queue(), ^{
          if (self.shouldCacheImage) {
            self.image = [UIImage imageNamed:_URL.path.lastPathComponent];
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
              self.animatedImage = animatedImage;
            } else {
              self.image = nonAnimatedImage;
            }
          }

          _imageLoaded = YES;
          /* We want to maintain the order that currentImageQuality is set regardless of the calling thread,
           so always use a dispatch_async to ensure that we queue the operations in the correct order.
           (see comment in displayDidFinish) */
          dispatch_async(dispatch_get_main_queue(), ^{
            self.currentImageQuality = 1.0;
          });
          if (_delegateFlags.delegateDidLoadImage) {
            [_delegate imageNode:self didLoadImage:self.image];
          }
        });
      }
    } else {
      __weak __typeof__(self) weakSelf = self;
      void (^finished)(id <ASImageContainerProtocol>, NSError *, id downloadIdentifier) = ^(id <ASImageContainerProtocol>imageContainer, NSError *error, id downloadIdentifier) {
        __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
          return;
        }

        ASDN::MutexLocker l(strongSelf->__instanceLock__);
        
        //Getting a result back for a different download identifier, download must not have been successfully canceled
        if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
            return;
        }

        if (imageContainer != nil) {
          strongSelf->_imageLoaded = YES;
          if ([imageContainer asdk_animatedImageData] && _downloaderFlags.downloaderImplementsAnimatedImage) {
            strongSelf.animatedImage = [_downloader animatedImageWithData:[imageContainer asdk_animatedImageData]];
          } else {
            strongSelf.image = [imageContainer asdk_image];
          }
          dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf->_currentImageQuality = 1.0;
          });
        }

        strongSelf->_downloadIdentifier = nil;

        strongSelf->_cacheUUID = nil;

        if (imageContainer != nil) {
          if (strongSelf->_delegateFlags.delegateDidLoadImage) {
            [strongSelf->_delegate imageNode:strongSelf didLoadImage:strongSelf.image];
          }
        }
        else if (error && strongSelf->_delegateFlags.delegateDidFailWithError) {
          [strongSelf->_delegate imageNode:strongSelf didFailWithError:error];
        }
      };

      if (_cache != nil) {
        NSUUID *cacheUUID = [NSUUID UUID];
        _cacheUUID = cacheUUID;

        void (^cacheCompletion)(id <ASImageContainerProtocol>) = ^(id <ASImageContainerProtocol> imageContainer) {
          // If the cache UUID changed, that means this request was cancelled.
          if (!ASObjectIsEqual(_cacheUUID, cacheUUID)) {
            return;
          }
          
          if ([imageContainer asdk_image] == nil && _downloader != nil) {
            [self _downloadImageWithCompletion:finished];
          } else {
            finished(imageContainer, nil, nil);
          }
        };
        
        if (_cacheFlags.cacheSupportsCachedImage) {
          [_cache cachedImageWithURL:_URL
                       callbackQueue:dispatch_get_main_queue()
                          completion:cacheCompletion];
        }
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

  ASDN::MutexLocker l(__instanceLock__);
  if (_delegateFlags.delegateDidFinishDecoding && self.layer.contents != nil) {
    /* We store the image quality in _currentImageQuality whenever _image is set. On the following displayDidFinish, we'll know that
     _currentImageQuality is the quality of the image that has just finished rendering. In order for this to be accurate, we
     need to be sure we are on main thread when we set _currentImageQuality. Otherwise, it is possible for _currentImageQuality
     to be modified at a point where it is too late to cancel the main thread's previous display (the final sentinel check has passed), 
     but before the displayDidFinish of the previous display pass is called. In this situation, displayDidFinish would be called and we
     would set _renderedImageQuality to the new _currentImageQuality, but the actual quality of the rendered image should be the previous 
     value stored in _currentImageQuality. */

    _renderedImageQuality = _currentImageQuality;
    [self.delegate imageNodeDidFinishDecoding:self];
  }
}

@end
