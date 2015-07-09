/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASMultiplexImageNode.h"

#import <AssetsLibrary/AssetsLibrary.h>

#import <Photos/Photos.h>

#import <libkern/OSAtomic.h>

#import "ASAvailability.h"
#import "ASBaseDefines.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASLog.h"

#if !AS_IOS8_SDK_OR_LATER
#error ASMultiplexImageNode can be used on iOS 7, but must be linked against the iOS 8 SDK.
#endif

NSString *const ASMultiplexImageNodeErrorDomain = @"ASMultiplexImageNodeErrorDomain";

static NSString *const kAssetsLibraryURLScheme = @"assets-library";
static NSString *const kPHAssetURLScheme = @"ph";
static NSString *const kPHAssetURLPrefix = @"ph://";

/**
  @abstract Signature for the block to be performed after an image has loaded.
  @param image The image that was loaded, or nil if no image was loaded.
  @param imageIdentifier The identifier of the image that was loaded, or nil if no image was loaded.
  @param error An error describing why an image couldn't be loaded, if it failed to load; nil otherwise.
 */
typedef void(^ASMultiplexImageLoadCompletionBlock)(UIImage *image, id imageIdentifier, NSError *error);

@interface ASMultiplexImageNode ()
{
@private
  // Core.
  id<ASImageCacheProtocol> _cache;
  id<ASImageDownloaderProtocol> _downloader;

  __weak id<ASMultiplexImageNodeDelegate> _delegate;
  struct {
    unsigned int downloadStart:1;
    unsigned int downloadProgress:1;
    unsigned int downloadFinish:1;
    unsigned int updatedImageDisplayFinish:1;
    unsigned int updatedImage:1;
    unsigned int displayFinish:1;
  } _delegateFlags;

  __weak id<ASMultiplexImageNodeDataSource> _dataSource;
  struct {
    unsigned int image:1;
    unsigned int URL:1;
  } _dataSourceFlags;

  // Image flags.
  BOOL _downloadsIntermediateImages; // Defaults to NO.
  OSSpinLock _imageIdentifiersLock;
  NSArray *_imageIdentifiers;
  id _loadedImageIdentifier;
  id _loadingImageIdentifier;
  id _displayedImageIdentifier;

  // Networking.
  id _downloadIdentifier;
}

//! @abstract Read-write redeclaration of property declared in ASMultiplexImageNode.h.
@property (nonatomic, readwrite, copy) id loadedImageIdentifier;

//! @abstract The image identifier that's being loaded by _loadNextImageWithCompletion:.
@property (nonatomic, readwrite, copy) id loadingImageIdentifier;

/**
  @abstract Returns the next image identifier that should be downloaded.
  @discussion This method obeys and reflects the value of `downloadsIntermediateImages`.
  @result The next image identifier, from `_imageIdentifiers`, that should be downloaded, or nil if no image should be downloaded next.
 */
- (id)_nextImageIdentifierToDownload;

/**
  @abstract Returns the best image that is immediately available from our datasource without downloading or hitting the cache.
  @param imageIdentifierOut Upon return, the image identifier for the returned image; nil otherwise.
  @discussion This method exclusively uses the data source's -multiplexImageNode:imageForIdentifier: method to return images. It does not fetch from the cache or kick off downloading.
  @result The best UIImage available immediately; nil if no image is immediately available.
 */
- (UIImage *)_bestImmediatelyAvailableImageFromDataSource:(id *)imageIdentifierOut;

/**
  @abstract Loads and displays the next image in the receiver's loading sequence.
  @discussion This method obeys `downloadsIntermediateImages`. This method has no effect if nothing further should be loaded, as indicated by `_nextImageIdentifierToDownload`. This method will load the next image from the data-source, if possible; otherwise, the session's image cache will be queried for the desired image, and as a last resort, the image will be downloaded.
 */
- (void)_loadNextImage;

/**
  @abstract Fetches the image corresponding to the given imageIdentifier from the given URL from the session's image cache.
  @param imageIdentifier The identifier for the image to be fetched. May not be nil.
  @param imageURL The URL of the image to fetch. May not be nil.
  @param completionBlock The block to be performed when the image has been fetched from the cache, if possible. May not be nil.
    @param image The image fetched from the cache, if any.
  @discussion This method queries both the session's in-memory and on-disk caches (with preference for the in-memory cache).
 */
- (void)_fetchImageWithIdentifierFromCache:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image))completionBlock;

/**
  @abstract Loads the image corresponding to the given assetURL from the device's Assets Library.
  @param imageIdentifier The identifier for the image to be loaded. May not be nil.
  @param assetURL The assets-library URL (e.g., "assets-library://identifier") of the image to load, from ALAsset. May not be nil.
  @param completionBlock The block to be performed when the image has been loaded, if possible. May not be nil.
    @param image The image that was loaded. May be nil if no image could be downloaded.
    @param error An error describing why the load failed, if it failed; nil otherwise.
 */
- (void)_loadALAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock;

/**
  @abstract Loads the image corresponding to the given assetURL from the Photos framework.
  @param imageIdentifier The identifier for the image to be loaded. May not be nil.
  @param assetURL The photos framework URL (e.g., "ph://identifier") of the image to load, from PHAsset. May not be nil.
  @param completionBlock The block to be performed when the image has been loaded, if possible. May not be nil.
    @param image The image that was loaded. May be nil if no image could be downloaded.
    @param error An error describing why the load failed, if it failed; nil otherwise.
 */
- (void)_loadPHAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock;

/**
 @abstract Downloads the image corresponding to the given imageIdentifier from the given URL.
 @param imageIdentifier The identifier for the image to be downloaded. May not be nil.
 @param imageURL The URL of the image to downloaded. May not be nil.
 @param completionBlock The block to be performed when the image has been downloaded, if possible. May not be nil.
   @param image The image that was downloaded. May be nil if no image could be downloaded.
   @param error An error describing why the download failed, if it failed; nil otherwise.
 */
- (void)_downloadImageWithIdentifier:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image, NSError *error))completionBlock;

@end

@implementation ASMultiplexImageNode

#pragma mark - Getting Started / Tearing Down
- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader
{
  if (!(self = [super init]))
    return nil;

  _cache = cache;
  _downloader = downloader;

  return self;
}

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
  return [self initWithCache:nil downloader:nil]; // satisfy compiler
}

#pragma mark - ASDisplayNode Overrides
- (void)clearContents
{
  [super clearContents]; // This actually clears the contents, so we need to do this first for our displayedImageIdentifier to be meaningful.
  [self _setDisplayedImageIdentifier:nil withImage:nil];

  if (_downloadIdentifier) {
    [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
    _downloadIdentifier = nil;
  }
}

- (void)displayWillStart
{
  [super displayWillStart];

  [self fetchData];
}

- (void)fetchData
{
  [super fetchData];

  [self _loadImageIdentifiers];
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  // We may now be displaying the loaded identifier, if they're different.
  UIImage *displayedImage = self.image;
  if (displayedImage) {
    if (![_displayedImageIdentifier isEqual:_loadedImageIdentifier])
      [self _setDisplayedImageIdentifier:_loadedImageIdentifier withImage:displayedImage];

    // Delegateify
    if (_delegateFlags.displayFinish) {
      if ([NSThread isMainThread])
        [_delegate multiplexImageNodeDidFinishDisplay:self];
      else {
        __weak __typeof__(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
          __typeof__(self) strongSelf = weakSelf;
          if (!strongSelf)
            return;
          [strongSelf.delegate multiplexImageNodeDidFinishDisplay:strongSelf];
        });
      }
    }
  }
}

#pragma mark - Core

- (void)setDelegate:(id <ASMultiplexImageNodeDelegate>)delegate
{
  if (_delegate == delegate)
    return;

  _delegate = delegate;
  _delegateFlags.downloadStart = [_delegate respondsToSelector:@selector(multiplexImageNode:didStartDownloadOfImageWithIdentifier:)];
  _delegateFlags.downloadProgress = [_delegate respondsToSelector:@selector(multiplexImageNode:didUpdateDownloadProgress:forImageWithIdentifier:)];
  _delegateFlags.downloadFinish = [_delegate respondsToSelector:@selector(multiplexImageNode:didFinishDownloadingImageWithIdentifier:error:)];
  _delegateFlags.updatedImageDisplayFinish = [_delegate respondsToSelector:@selector(multiplexImageNode:didDisplayUpdatedImage:withIdentifier:)];
  _delegateFlags.updatedImage = [_delegate respondsToSelector:@selector(multiplexImageNode:didUpdateImage:withIdentifier:fromImage:withIdentifier:)];
  _delegateFlags.displayFinish = [_delegate respondsToSelector:@selector(multiplexImageNodeDidFinishDisplay:)];
}


- (void)setDataSource:(id <ASMultiplexImageNodeDataSource>)dataSource
{
  if (_dataSource == dataSource)
    return;

  _dataSource = dataSource;
  _dataSourceFlags.image = [_dataSource respondsToSelector:@selector(multiplexImageNode:imageForImageIdentifier:)];
  _dataSourceFlags.URL = [_dataSource respondsToSelector:@selector(multiplexImageNode:URLForImageIdentifier:)];
}

#pragma mark -

#pragma mark -

- (NSArray *)imageIdentifiers
{
  OSSpinLockLock(&_imageIdentifiersLock);
  NSArray *imageIdentifiers = [_imageIdentifiers copy];
  OSSpinLockUnlock(&_imageIdentifiersLock);
  return imageIdentifiers;
}

- (void)setImageIdentifiers:(NSArray *)imageIdentifiers
{
  OSSpinLockLock(&_imageIdentifiersLock);

  if (_imageIdentifiers == imageIdentifiers) {
    OSSpinLockUnlock(&_imageIdentifiersLock);
    return;
  }
  
  _imageIdentifiers = [imageIdentifiers copy];
  OSSpinLockUnlock(&_imageIdentifiersLock);
}

- (void)reloadImageIdentifierSources
{
  // setting this to nil makes the node think it has not downloaded any images
  _loadedImageIdentifier = nil;
  [self _loadImageIdentifiers];
}

#pragma mark -


#pragma mark - Core Internal
- (void)_setDisplayedImageIdentifier:(id)displayedImageIdentifier withImage:(UIImage *)image
{
  if (_displayedImageIdentifier == displayedImageIdentifier)
    return;

  _displayedImageIdentifier = [displayedImageIdentifier copy];

  // Delegateify.
  // Note that we're using the params here instead of self.image and _displayedImageIdentifier because those can change before the async block below executes.
  if (_delegateFlags.updatedImageDisplayFinish) {
    if ([NSThread isMainThread])
      [_delegate multiplexImageNode:self didDisplayUpdatedImage:image withIdentifier:displayedImageIdentifier];
    else {
      __weak __typeof__(self) weakSelf = self;
      dispatch_async(dispatch_get_main_queue(), ^{
        __typeof__(self) strongSelf = weakSelf;
        if (!strongSelf)
          return;
        [strongSelf.delegate multiplexImageNode:strongSelf didDisplayUpdatedImage:image withIdentifier:displayedImageIdentifier];
      });
    }
  }
}

- (void)_setDownloadIdentifier:(id)downloadIdentifier
{
  if (_downloadIdentifier == downloadIdentifier)
    return;

  [_downloader cancelImageDownloadForIdentifier:_downloadIdentifier];
  _downloadIdentifier = downloadIdentifier;
}


#pragma mark - Image Loading Machinery

- (void)_loadImageIdentifiers
{
  // Kill any in-flight downloads.
  [self _setDownloadIdentifier:nil];

  // Grab the best possible image we can load right now.
  id bestImmediatelyAvailableImageIdentifier = nil;
  UIImage *bestImmediatelyAvailableImage = [self _bestImmediatelyAvailableImageFromDataSource:&bestImmediatelyAvailableImageIdentifier];
  ASMultiplexImageNodeLogDebug(@"[%p] Best immediately available image identifier is %@", self, bestImmediatelyAvailableImageIdentifier);

  // Load it. This kicks off cache fetching/downloading, as appropriate.
  [self _finishedLoadingImage:bestImmediatelyAvailableImage forIdentifier:bestImmediatelyAvailableImageIdentifier error:nil];
}

- (UIImage *)_bestImmediatelyAvailableImageFromDataSource:(id *)imageIdentifierOut
{
  OSSpinLockLock(&_imageIdentifiersLock);

  // If we don't have any identifiers to load or don't implement the image DS method, bail.
  if ([_imageIdentifiers count] == 0 || !_dataSourceFlags.image) {
    OSSpinLockUnlock(&_imageIdentifiersLock);
    return nil;
  }

  // Grab the best available image from the data source.
  for (id imageIdentifier in _imageIdentifiers) {
    UIImage *image = [_dataSource multiplexImageNode:self imageForImageIdentifier:imageIdentifier];
    if (image) {
      if (imageIdentifierOut) {
        *imageIdentifierOut = [imageIdentifier copy];
      }

      OSSpinLockUnlock(&_imageIdentifiersLock);
      return image;
    }
  }

  OSSpinLockUnlock(&_imageIdentifiersLock);
  return nil;
}


#pragma mark -
- (id)_nextImageIdentifierToDownload
{
  OSSpinLockLock(&_imageIdentifiersLock);

  // If we've already loaded the best identifier, we've got nothing else to do.
  id bestImageIdentifier = ([_imageIdentifiers count] > 0) ? _imageIdentifiers[0] : nil;
  if (!bestImageIdentifier || [_loadedImageIdentifier isEqual:bestImageIdentifier]) {
    OSSpinLockUnlock(&_imageIdentifiersLock);
    return nil;
  }

  id nextImageIdentifierToDownload = nil;

  // If we're not supposed to download intermediate images, load the best identifier we've got.
  if (!_downloadsIntermediateImages) {
    nextImageIdentifierToDownload = bestImageIdentifier;
  }
  // Otherwise, load progressively.
  else {
    NSUInteger loadedIndex = [_imageIdentifiers indexOfObject:_loadedImageIdentifier];

    // If nothing has loaded yet, load the worst identifier.
    if (loadedIndex == NSNotFound) {
      nextImageIdentifierToDownload = [_imageIdentifiers lastObject];
    }
    // Otherwise, load the next best identifier (if there is one)
    else if (loadedIndex > 0) {
      nextImageIdentifierToDownload = _imageIdentifiers[loadedIndex - 1];
    }
  }

  OSSpinLockUnlock(&_imageIdentifiersLock);

  return nextImageIdentifierToDownload;
}

- (void)_loadNextImage
{
  // Determine the next identifier to load (if any).
  id nextImageIdentifier = [self _nextImageIdentifierToDownload];
  if (!nextImageIdentifier) {
    [self _finishedLoadingImage:nil forIdentifier:nil error:nil];
    return;
  }

  self.loadingImageIdentifier = nextImageIdentifier;

  __weak __typeof__(self) weakSelf = self;
  ASMultiplexImageLoadCompletionBlock finishedLoadingBlock = ^(UIImage *image, id imageIdentifier, NSError *error) {
    __typeof__(self) strongSelf = weakSelf;
    if (!strongSelf)
      return;

    // Only nil out the loading identifier if the loading identifier hasn't changed.
    if ([strongSelf.loadingImageIdentifier isEqual:nextImageIdentifier]) {
      strongSelf.loadingImageIdentifier = nil;
    }
    [strongSelf _finishedLoadingImage:image forIdentifier:imageIdentifier error:error];
  };

  ASMultiplexImageNodeLogDebug(@"[%p] Loading next image, ident: %@", self, nextImageIdentifier);

  // Ask our data-source if it's got this image.
  if (_dataSourceFlags.image) {
    UIImage *image = [_dataSource multiplexImageNode:self imageForImageIdentifier:nextImageIdentifier];
    if (image) {
      ASMultiplexImageNodeLogDebug(@"[%p] Acquired next image (%@) from data-source", self, nextImageIdentifier);
      finishedLoadingBlock(image, nextImageIdentifier, nil);
      return;
    }
  }

  NSURL *nextImageURL = (_dataSourceFlags.URL) ? [_dataSource multiplexImageNode:self URLForImageIdentifier:nextImageIdentifier] : nil;
  // If we fail to get a URL for the image, we have no source and can't proceed.
  if (!nextImageURL) {
    ASMultiplexImageNodeLogError(@"[%p] Could not acquire URL for next image (%@). Bailing.", self, nextImageIdentifier);
    finishedLoadingBlock(nil, nil, [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodeNoSourceForImage userInfo:nil]);
    return;
  }

  // If it's an assets-library URL, we need to fetch it from the assets library.
  if ([[nextImageURL scheme] isEqualToString:kAssetsLibraryURLScheme]) {
    // Load the asset.
    [self _loadALAssetWithIdentifier:nextImageIdentifier URL:nextImageURL completion:^(UIImage *downloadedImage, NSError *error) {
      ASMultiplexImageNodeCLogDebug(@"[%p] Acquired next image (%@) from asset library", weakSelf, nextImageIdentifier);
      finishedLoadingBlock(downloadedImage, nextImageIdentifier, error);
    }];
  }
  // Likewise, if it's a iOS 8 Photo asset, we need to fetch it accordingly.
  else if (AS_AT_LEAST_IOS8 && [[nextImageURL scheme] isEqualToString:kPHAssetURLScheme]) {
    [self _loadPHAssetWithIdentifier:nextImageIdentifier URL:nextImageURL completion:^(UIImage *image, NSError *error) {
      ASMultiplexImageNodeCLogDebug(@"[%p] Acquired next image (%@) from Photos Framework", weakSelf, nextImageIdentifier);
      finishedLoadingBlock(image, nextImageIdentifier, error);
    }];
  }
  else // Otherwise, it's a web URL that we can download.
  {
    // First, check the cache.
    [self _fetchImageWithIdentifierFromCache:nextImageIdentifier URL:nextImageURL completion:^(UIImage *imageFromCache) {
      __typeof__(self) strongSelf = weakSelf;
      if (!strongSelf)
        return;

      // If we had a cache-hit, we're done.
      if (imageFromCache) {
        ASMultiplexImageNodeCLogDebug(@"[%p] Acquired next image (%@) from cache", strongSelf, nextImageIdentifier);
        finishedLoadingBlock(imageFromCache, nextImageIdentifier, nil);
        return;
      }

      // If the next image to load has changed, bail.
      if (![[strongSelf _nextImageIdentifierToDownload] isEqual:nextImageIdentifier]) {
        finishedLoadingBlock(nil, nil, [NSError errorWithDomain:ASMultiplexImageNodeErrorDomain code:ASMultiplexImageNodeErrorCodeBestImageIdentifierChanged userInfo:nil]);
        return;
      }

      // Otherwise, we've got to download it.
      [strongSelf _downloadImageWithIdentifier:nextImageIdentifier URL:nextImageURL completion:^(UIImage *downloadedImage, NSError *error) {
        ASMultiplexImageNodeCLogDebug(@"[%p] Acquired next image (%@) from download", strongSelf, nextImageIdentifier);
        finishedLoadingBlock(downloadedImage, nextImageIdentifier, error);
      }];
    }];
  }
}

- (void)_loadALAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(assetURL, @"assetURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];

  [assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
    ALAssetRepresentation *representation = [asset defaultRepresentation];
    CGImageRef coreGraphicsImage = [representation fullScreenImage];

    UIImage *downloadedImage = (coreGraphicsImage ? [UIImage imageWithCGImage:coreGraphicsImage] : nil);
    completionBlock(downloadedImage, nil);
  } failureBlock:^(NSError *error) {
    completionBlock(nil, error);
  }];
}

- (void)_loadPHAssetWithIdentifier:(id)imageIdentifier URL:(NSURL *)assetURL completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssert(AS_AT_LEAST_IOS8, @"PhotosKit is unavailable on iOS 7.");
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(assetURL, @"assetURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  // Get the PHAsset itself.
  ASDisplayNodeAssertTrue([[assetURL absoluteString] hasPrefix:kPHAssetURLPrefix]);
  NSString *assetIdentifier = [[assetURL absoluteString] substringFromIndex:[kPHAssetURLPrefix length]];
  PHFetchResult *assetFetchResult = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetIdentifier] options:nil];
  if ([assetFetchResult count] == 0) {
    // Error.
    completionBlock(nil, nil);
    return;
  }

  // Get the best image we can.
  PHAsset *imageAsset = [assetFetchResult firstObject];

  PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
  requestOptions.version = PHImageRequestOptionsVersionCurrent;
  requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  requestOptions.resizeMode = PHImageRequestOptionsResizeModeNone;

  [[PHImageManager defaultManager] requestImageForAsset:imageAsset
                                             targetSize:CGSizeMake(2048.0, 2048.0) // Ideally we would use PHImageManagerMaximumSize and kill the options, but we get back nil when requesting images of video assets. rdar://18447788
                                            contentMode:PHImageContentModeDefault
                                                options:requestOptions
                                          resultHandler:^(UIImage *image, NSDictionary *info) {
                                            completionBlock(image, info[PHImageErrorKey]);
                                          }];
}

- (void)_fetchImageWithIdentifierFromCache:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(imageURL, @"imageURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  if (_cache) {
    [_cache fetchCachedImageWithURL:imageURL callbackQueue:dispatch_get_main_queue() completion:^(CGImageRef coreGraphicsImageFromCache) {
      UIImage *imageFromCache = (coreGraphicsImageFromCache ? [UIImage imageWithCGImage:coreGraphicsImageFromCache] : nil);
      completionBlock(imageFromCache);
    }];
  }
  // If we don't have a cache, just fail immediately.
  else {
    completionBlock(nil);
  }
}

- (void)_downloadImageWithIdentifier:(id)imageIdentifier URL:(NSURL *)imageURL completion:(void (^)(UIImage *image, NSError *error))completionBlock
{
  ASDisplayNodeAssertNotNil(imageIdentifier, @"imageIdentifier is required");
  ASDisplayNodeAssertNotNil(imageURL, @"imageURL is required");
  ASDisplayNodeAssertNotNil(completionBlock, @"completionBlock is required");

  // Delegate (start)
  if (_delegateFlags.downloadStart)
    [_delegate multiplexImageNode:self didStartDownloadOfImageWithIdentifier:imageIdentifier];

  __weak __typeof__(self) weakSelf = self;
  void (^downloadProgressBlock)(CGFloat) = nil;
  if (_delegateFlags.downloadProgress) {
    downloadProgressBlock = ^(CGFloat progress) {
      __typeof__(self) strongSelf = weakSelf;
      if (!strongSelf)
        return;
      [strongSelf.delegate multiplexImageNode:strongSelf didUpdateDownloadProgress:progress forImageWithIdentifier:imageIdentifier];
    };
  }

  // Download!
  [self _setDownloadIdentifier:[_downloader downloadImageWithURL:imageURL
                                                   callbackQueue:dispatch_get_main_queue()
                                           downloadProgressBlock:downloadProgressBlock
                                                      completion:^(CGImageRef coreGraphicsImage, NSError *error) {
                                                        // We dereference iVars directly, so we can't have weakSelf going nil on us.
                                                        __typeof__(self) strongSelf = weakSelf;
                                                        if (!strongSelf)
                                                          return;

                                                        UIImage *downloadedImage = (coreGraphicsImage ? [UIImage imageWithCGImage:coreGraphicsImage] : nil);
                                                        completionBlock(downloadedImage, error);

                                                        // Delegateify.
                                                        if (strongSelf->_delegateFlags.downloadFinish)
                                                          [strongSelf->_delegate multiplexImageNode:weakSelf didFinishDownloadingImageWithIdentifier:imageIdentifier error:error];
                                                      }]];
}

#pragma mark -
- (void)_finishedLoadingImage:(UIImage *)image forIdentifier:(id)imageIdentifier error:(NSError *)error
{
  // If we failed to load, we stop the loading process.
  // Note that if we bailed before we began downloading because the best identifier changed, we don't bail, but rather just begin loading the best image identifier.
  if (error && error.code != ASMultiplexImageNodeErrorCodeBestImageIdentifierChanged)
    return;

  OSSpinLockLock(&_imageIdentifiersLock);
  NSUInteger imageIdentifierCount = [_imageIdentifiers count];
  OSSpinLockUnlock(&_imageIdentifiersLock);

  // Update our image if we got one, or if we're not supposed to display one at all.
  // We explicitly perform this check because our datasource often doesn't give back immediately available images, even though we might have downloaded one already.
  // Because we seed this call with bestImmediatelyAvailableImageFromDataSource, we must be careful not to trample an existing image.
  if (image || imageIdentifierCount == 0) {
    ASMultiplexImageNodeLogDebug(@"[%p] loaded -> displaying (%@, %@)", self, imageIdentifier, image);
    id previousIdentifier = self.loadedImageIdentifier;
    UIImage *previousImage = self.image;

    self.loadedImageIdentifier = imageIdentifier;
    self.image = image;

    if (_delegateFlags.updatedImage) {
      [_delegate multiplexImageNode:self didUpdateImage:image withIdentifier:imageIdentifier fromImage:previousImage withIdentifier:previousIdentifier];
    }

  }

  // Load our next image, if we have one to load.
  if ([self _nextImageIdentifierToDownload])
    [self _loadNextImage];
}

@end
