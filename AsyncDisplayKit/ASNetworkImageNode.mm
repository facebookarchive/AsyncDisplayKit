/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASNetworkImageNode.h"

#import "ASBasicImageDownloader.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASEqualityHelpers.h"
#import "ASThread.h"
#import "ASInternalHelpers.h"

#if PIN_REMOTE_IMAGE
#import "ASPINRemoteImageDownloader.h"
#endif

@interface ASNetworkImageNode ()
{
  ASDN::RecursiveMutex _lock;
  __weak id<ASImageCacheProtocol, ASImageCacheProtocolDeprecated> _cache;
  __weak id<ASImageDownloaderProtocol, ASImageDownloaderProtocolDeprecated> _downloader;

  // Only access any of these with _lock.
  __weak id<ASNetworkImageNodeDelegate> _delegate;

  NSURL *_URL;
  UIImage *_defaultImage;

  NSUUID *_cacheUUID;
  id _downloadIdentifier;

  BOOL _imageLoaded;
  
  BOOL _delegateSupportsDidStartFetchingData;
  BOOL _delegateSupportsDidFailWithError;
  BOOL _delegateSupportsImageNodeDidFinishDecoding;
  
  //set on init only
  BOOL _downloaderSupportsNewProtocol;
  BOOL _downloaderImplementsSetProgress;
  BOOL _downloaderImplementsSetPriority;
  
  BOOL _cacheSupportsNewProtocol;
  BOOL _cacheSupportsClearing;
}
@end

@implementation ASNetworkImageNode

- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = (id<ASImageCacheProtocol, ASImageCacheProtocolDeprecated>)cache;
  _downloader = (id<ASImageDownloaderProtocol, ASImageDownloaderProtocolDeprecated>)downloader;
  
  ASDisplayNodeAssert([downloader respondsToSelector:@selector(downloadImageWithURL:callbackQueue:downloadProgress:completion:)] || [downloader respondsToSelector:@selector(downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:)], @"downloader must respond to either downloadImageWithURL:callbackQueue:downloadProgress:completion: or downloadImageWithURL:callbackQueue:downloadProgressBlock:completion:.");
  
  _downloaderSupportsNewProtocol = [downloader respondsToSelector:@selector(downloadImageWithURL:callbackQueue:downloadProgress:completion:)];
  
  ASDisplayNodeAssert([cache respondsToSelector:@selector(cachedImageWithURL:callbackQueue:completion:)] || [cache respondsToSelector:@selector(fetchCachedImageWithURL:callbackQueue:completion:)], @"cacher must respond to either cachedImageWithURL:callbackQueue:completion: or fetchCachedImageWithURL:callbackQueue:completion:");
  
  _downloaderImplementsSetProgress = [downloader respondsToSelector:@selector(setProgressImageBlock:callbackQueue:withDownloadIdentifier:)];
  _downloaderImplementsSetPriority = [downloader respondsToSelector:@selector(setPriority:withDownloadIdentifier:)];
  
  _cacheSupportsNewProtocol = [cache respondsToSelector:@selector(cachedImageWithURL:callbackQueue:completion:)];
  _cacheSupportsClearing = [cache respondsToSelector:@selector(clearFetchedImageFromCacheWithURL:)];
  
  _shouldCacheImage = YES;
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
  ASDN::MutexLocker l(_lock);

  if (ASObjectIsEqual(URL, _URL)) {
    return;
  }

  [self _cancelImageDownload];
  _imageLoaded = NO;

  _URL = URL;

  if (reset || _URL == nil)
    self.image = _defaultImage;
  
  if (self.interfaceState & ASInterfaceStateFetchData) {
    [self fetchData];
  }
}

- (NSURL *)URL
{
  ASDN::MutexLocker l(_lock);
  return _URL;
}

- (void)setDefaultImage:(UIImage *)defaultImage
{
  ASDN::MutexLocker l(_lock);

  if (ASObjectIsEqual(defaultImage, _defaultImage)) {
    return;
  }
  _defaultImage = defaultImage;

  if (!_imageLoaded) {
    self.image = _defaultImage;
  }
}

- (UIImage *)defaultImage
{
  ASDN::MutexLocker l(_lock);
  return _defaultImage;
}

- (void)setDelegate:(id<ASNetworkImageNodeDelegate>)delegate
{
  ASDN::MutexLocker l(_lock);
  _delegate = delegate;
  
  _delegateSupportsDidStartFetchingData = [delegate respondsToSelector:@selector(imageNodeDidStartFetchingData:)];
  _delegateSupportsDidFailWithError = [delegate respondsToSelector:@selector(imageNode:didFailWithError:)];
  _delegateSupportsImageNodeDidFinishDecoding = [delegate respondsToSelector:@selector(imageNodeDidFinishDecoding:)];
}

- (id<ASNetworkImageNodeDelegate>)delegate
{
  ASDN::MutexLocker l(_lock);
  return _delegate;
}

/* displayWillStart in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)displayWillStart
{
  [super displayWillStart];

  [self fetchData];
  
  if (self.image == nil && _downloaderImplementsSetPriority) {
    ASDN::MutexLocker l(_lock);
    if (_downloadIdentifier != nil) {
      [_downloader setPriority:ASImageDownloaderPriorityImminent withDownloadIdentifier:_downloadIdentifier];
    }
  }
}

/* visibilityDidChange in ASMultiplexImageNode has a very similar implementation. Changes here are likely necessary
 in ASMultiplexImageNode as well. */
- (void)visibilityDidChange:(BOOL)isVisible
{
  if (_downloaderImplementsSetPriority) {
    ASDN::MutexLocker l(_lock);
    if (_downloadIdentifier != nil) {
      if (isVisible) {
        [_downloader setPriority:ASImageDownloaderPriorityVisible withDownloadIdentifier:_downloadIdentifier];
      } else {
        [_downloader setPriority:ASImageDownloaderPriorityPreload withDownloadIdentifier:_downloadIdentifier];
      }
    }
  }
  
  if (_downloaderImplementsSetProgress) {
    ASDN::MutexLocker l(_lock);
    
    if (_downloadIdentifier != nil) {
      __weak __typeof__(self) weakSelf = self;
      ASImageDownloaderProgressImage progress = nil;
      if (isVisible) {
        progress = ^(UIImage * _Nonnull progressImage, id _Nullable downloadIdentifier) {
          __typeof__(self) strongSelf = weakSelf;
          if (strongSelf == nil) {
            return;
          }
          
          ASDN::MutexLocker l(_lock);
          //Getting a result back for a different download identifier, download must not have been successfully canceled
          if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
            return;
          }
          
          strongSelf.image = progressImage;
        };
      }
      [_downloader setProgressImageBlock:progress callbackQueue:dispatch_get_main_queue() withDownloadIdentifier:_downloadIdentifier];
    }
  }
}

- (void)clearFetchedData
{
  [super clearFetchedData];

  {
    ASDN::MutexLocker l(_lock);

    [self _cancelImageDownload];
    self.image = _defaultImage;
    _imageLoaded = NO;
    if (_cacheSupportsClearing) {
      [_cache clearFetchedImageFromCacheWithURL:_URL];
    }
  }
}

- (void)fetchData
{
  [super fetchData];
  
  {
    ASDN::MutexLocker l(_lock);
    [self _lazilyLoadImageIfNecessary];
  }
}

#pragma mark - Private methods -- only call with lock.

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

- (void)_downloadImageWithCompletion:(void (^)(UIImage *image, NSError*, id downloadIdentifier))finished
{
  ASPerformBlockOnBackgroundThread(^{
    ASDN::MutexLocker l(_lock);
    if (_downloaderSupportsNewProtocol) {
      _downloadIdentifier = [_downloader downloadImageWithURL:_URL
                                                callbackQueue:dispatch_get_main_queue()
                                             downloadProgress:NULL
                                                   completion:^(UIImage * _Nullable image, NSError * _Nullable error, id  _Nullable downloadIdentifier) {
                                                     if (finished != NULL) {
                                                       finished(image, error, downloadIdentifier);
                                                     }
                                                   }];
    } else {
      _downloadIdentifier = [_downloader downloadImageWithURL:_URL
                                                callbackQueue:dispatch_get_main_queue()
                                        downloadProgressBlock:NULL
                                                   completion:^(CGImageRef responseImage, NSError *error) {
                                                     if (finished != NULL) {
                                                       finished([UIImage imageWithCGImage:responseImage], error, nil);
                                                     }
                                                   }];
    }
  });
}

- (void)_lazilyLoadImageIfNecessary
{
  if (!_imageLoaded && _URL != nil && _downloadIdentifier == nil) {
    {
      ASDN::MutexLocker l(_lock);
      if (_delegateSupportsDidStartFetchingData) {
        [_delegate imageNodeDidStartFetchingData:self];
      }
    }
    
    if (_URL.isFileURL) {
      {
        ASDN::MutexLocker l(_lock);

        dispatch_async(dispatch_get_main_queue(), ^{
          if (self.shouldCacheImage) {
            self.image = [UIImage imageNamed:_URL.path.lastPathComponent];
          } else {
            // First try to load the path directly, for efficiency assuming a developer who
            // doesn't want caching is trying to be as minimal as possible.
            self.image = [UIImage imageWithContentsOfFile:_URL.path];
            if (!self.image) {
              // If we couldn't find it, execute an -imageNamed:-like search so we can find resources even if the
              // extension is not provided in the path.  This allows the same path to work regardless of shouldCacheImage.
              NSString *filename = [[NSBundle mainBundle] pathForResource:_URL.path.lastPathComponent ofType:nil];
              if (filename) {
                self.image = [UIImage imageWithContentsOfFile:filename];
              }
            }
          }
          
          _imageLoaded = YES;
          [_delegate imageNode:self didLoadImage:self.image];
        });
      }
    } else {
      __weak __typeof__(self) weakSelf = self;
      void (^finished)(UIImage *, NSError *, id downloadIdentifier) = ^(UIImage *responseImage, NSError *error, id downloadIdentifier) {
        __typeof__(self) strongSelf = weakSelf;
        if (strongSelf == nil) {
          return;
        }

        {
          ASDN::MutexLocker l(strongSelf->_lock);
          
          //Getting a result back for a different download identifier, download must not have been successfully canceled
          if (ASObjectIsEqual(strongSelf->_downloadIdentifier, downloadIdentifier) == NO && downloadIdentifier != nil) {
              return;
          }

          if (responseImage != NULL) {
            strongSelf->_imageLoaded = YES;
            strongSelf.image = responseImage;
          }

          strongSelf->_downloadIdentifier = nil;

          strongSelf->_cacheUUID = nil;
        }

        {
          ASDN::MutexLocker l(strongSelf->_lock);
          if (responseImage != NULL) {
            [strongSelf->_delegate imageNode:strongSelf didLoadImage:strongSelf.image];
          }
          else if (error && _delegateSupportsDidFailWithError) {
            [strongSelf->_delegate imageNode:strongSelf didFailWithError:error];
          }
        }
      };

      if (_cache != nil) {
        NSUUID *cacheUUID = [NSUUID UUID];
        _cacheUUID = cacheUUID;

        void (^cacheCompletion)(UIImage *) = ^(UIImage *image) {
          // If the cache UUID changed, that means this request was cancelled.
          if (![_cacheUUID isEqual:cacheUUID]) {
            return;
          }
          
          if (image == NULL && _downloader != nil) {
            [self _downloadImageWithCompletion:finished];
          } else {
            finished(image, NULL, nil);
          }
        };
        
        if (_cacheSupportsNewProtocol) {
          [_cache cachedImageWithURL:_URL
                       callbackQueue:dispatch_get_main_queue()
                          completion:cacheCompletion];
        } else {
          [_cache fetchCachedImageWithURL:_URL
                            callbackQueue:dispatch_get_main_queue()
                               completion:^(CGImageRef image) {
                                 cacheCompletion([UIImage imageWithCGImage:image]);
                               }];
        }
      } else {
        [self _downloadImageWithCompletion:finished];
      }
    }
  }
}

#pragma mark - ASDisplayNode+Subclasses

- (void)asyncdisplaykit_asyncTransactionContainerStateDidChange
{
  if (self.asyncdisplaykit_asyncTransactionContainerState == ASAsyncTransactionContainerStateNoTransactions) {
    ASDN::MutexLocker l(_lock);
    if (self.layer.contents != nil && _delegateSupportsImageNodeDidFinishDecoding) {
      [self.delegate imageNodeDidFinishDecoding:self];
    }
  }
}

@end
