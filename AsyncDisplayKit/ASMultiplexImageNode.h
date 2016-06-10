//
//  ASMultiplexImageNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if TARGET_OS_IOS

#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/ASImageProtocols.h>
#import <Photos/Photos.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASMultiplexImageNodeDelegate;
@protocol ASMultiplexImageNodeDataSource;

typedef id<NSCopying, NSObject> ASImageIdentifier;

extern NSString *const ASMultiplexImageNodeErrorDomain;

/**
 * ASMultiplexImageNode error codes.
 */
typedef NS_ENUM(NSUInteger, ASMultiplexImageNodeErrorCode) {
  /**
   * Indicates that the data source didn't provide a source for an image identifier.
   */
  ASMultiplexImageNodeErrorCodeNoSourceForImage = 0,

  /**
   * Indicates that the best image identifier changed before a download for a worse identifier began.
   */
  ASMultiplexImageNodeErrorCodeBestImageIdentifierChanged,

  /**
   * Indicates that the Photos framework returned no image and no error.
   * This may happen if the image is in iCloud and the user did not specify `allowsNetworkAccess`
   * in their image request.
   */
  ASMultiplexImageNodeErrorCodePhotosImageManagerFailedWithoutError,
  
  /**
   * Indicates that the image node could not retrieve the PHAsset for a given asset identifier.
   * This typically means that the user has not given Photos framework permissions yet or the asset 
   * has been removed from the device.
   */
  ASMultiplexImageNodeErrorCodePHAssetIsUnavailable
};


/**
 * @abstract ASMultiplexImageNode is an image node that can load and display multiple versions of an image.  For
 * example, it can display a low-resolution version of an image while the high-resolution version is loading.
 *
 * @discussion ASMultiplexImageNode begins loading images when its resource can either return a UIImage directly, or a URL the image node should load.
 */
@interface ASMultiplexImageNode : ASImageNode

/**
 * @abstract The designated initializer.
 * @param cache The object that implements a cache of images for the image node.
 * @param downloader The object that implements image downloading for the image node.
 * @discussion If `cache` is nil, the receiver will not attempt to retrieve images from a cache before downloading them.
 * @returns An initialized ASMultiplexImageNode.
 */
- (instancetype)initWithCache:(nullable id<ASImageCacheProtocol>)cache downloader:(nullable id<ASImageDownloaderProtocol>)downloader NS_DESIGNATED_INITIALIZER;

/**
 * @abstract The delegate, which must conform to the <ASMultiplexImageNodeDelegate> protocol.
 */
@property (nonatomic, readwrite, weak) id <ASMultiplexImageNodeDelegate> delegate;

/**
 * @abstract The data source, which must conform to the <ASMultiplexImageNodeDataSource> protocol.
 * @discussion This value is required for ASMultiplexImageNode to load images.
 */
@property (nonatomic, readwrite, weak) id <ASMultiplexImageNodeDataSource> dataSource;

/**
 * @abstract Whether the receiver should download more than just its highest-quality image.  Defaults to NO.
 *
 * @discussion ASMultiplexImageNode immediately loads and displays the first image specified in <imageIdentifiers> (its
 * highest-quality image).  If that image is not immediately available or cached, the node can download and display
 * lesser-quality images.  Set `downloadsIntermediateImages` to YES to enable this behaviour.
 */
@property (nonatomic, readwrite, assign) BOOL downloadsIntermediateImages;

/**
 * @abstract An array of identifiers representing various versions of an image for ASMultiplexImageNode to display.
 *
 * @discussion An identifier can be any object that conforms to NSObject and NSCopying.  The array should be in
 * decreasing order of image quality -- that is, the first identifier in the array represents the best version.
 *
 * @see <downloadsIntermediateImages> for more information on the image loading process.
 */
@property (nonatomic, readwrite, copy) NSArray<ASImageIdentifier> *imageIdentifiers;

/**
 * @abstract Notify the receiver SSAA that its data source has new UIImages or NSURLs available for <imageIdentifiers>.
 *
 * @discussion If a higher-quality image than is currently displayed is now available, it will be loaded.
 */
- (void)reloadImageIdentifierSources;

/**
 * @abstract The identifier for the last image that the receiver loaded, or nil.
 *
 * @discussion This value may differ from <displayedImageIdentifier> if the image hasn't yet been displayed.
 */
@property (nullable, nonatomic, readonly) ASImageIdentifier loadedImageIdentifier;

/**
 * @abstract The identifier for the image that the receiver is currently displaying, or nil.
 */
@property (nullable, nonatomic, readonly) ASImageIdentifier displayedImageIdentifier;

/**
 * @abstract If the downloader implements progressive image rendering and this value is YES progressive renders of the
 * image will be displayed as the image downloads. Regardless of this properties value, progress renders will
 * only occur when the node is visible. Defaults to YES.
 */
@property (nonatomic, assign, readwrite) BOOL shouldRenderProgressImages;

#if TARGET_OS_IOS
/**
 * @abstract The image manager that this image node should use when requesting images from the Photos framework. If this is `nil` (the default), then `PHImageManager.defaultManager` is used.
 
 * @see `+[NSURL URLWithAssetLocalIdentifier:targetSize:contentMode:options:]` below.
 */
@property (nullable, nonatomic, strong) PHImageManager *imageManager;
#endif
@end


#pragma mark -
/**
 * The methods declared by the ASMultiplexImageNodeDelegate protocol allow the adopting delegate to respond to
 * notifications such as began, progressed and finished downloading, updated and displayed an image.
 */
@protocol ASMultiplexImageNodeDelegate <NSObject>

@optional
/**
 * @abstract Notification that the image node began downloading an image.
 * @param imageNode The sender.
 * @param imageIdentifier The identifier for the image that is downloading.
 */
- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode didStartDownloadOfImageWithIdentifier:(id)imageIdentifier;

/**
 * @abstract Notification that the image node's download progressed.
 * @param imageNode The sender.
 * @param downloadProgress The progress of the download.  Value is between 0.0 and 1.0.
 * @param imageIdentifier The identifier for the image that is downloading.
 */
- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode
 didUpdateDownloadProgress:(CGFloat)downloadProgress
    forImageWithIdentifier:(ASImageIdentifier)imageIdentifier;

/**
 * @abstract Notification that the image node's download has finished.
 * @param imageNode The sender.
 * @param imageIdentifier The identifier for the image that finished downloading.
 * @param error The error that occurred while downloading, if one occurred; nil otherwise.
 */
- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode
didFinishDownloadingImageWithIdentifier:(ASImageIdentifier)imageIdentifier
                     error:(nullable NSError *)error;

/**
 * @abstract Notification that the image node's image was updated.
 * @param imageNode The sender.
 * @param image The new image, ready for display.
 * @param imageIdentifier The identifier for `image`.
 * @param previousImage The old, previously-loaded image.
 * @param previousImageIdentifier The identifier for `previousImage`.
 * @note This method does not indicate that `image` has been displayed.
 * @see <[ASMultiplexImageNodeDelegate multiplexImageNode:didDisplayUpdatedImage:withIdentifier:]>.
 */
- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode
            didUpdateImage:(nullable UIImage *)image
            withIdentifier:(nullable ASImageIdentifier)imageIdentifier
                 fromImage:(nullable UIImage *)previousImage
            withIdentifier:(nullable ASImageIdentifier)previousImageIdentifier;

/**
 * @abstract Notification that the image node displayed a new image.
 * @param imageNode The sender.
 * @param image The new image, now being displayed.
 * @param imageIdentifier The identifier for `image`.
 * @discussion This method is only called when `image` changes, and not on subsequent redisplays of the same image.
 */
- (void)multiplexImageNode:(ASMultiplexImageNode *)imageNode
    didDisplayUpdatedImage:(nullable UIImage *)image
            withIdentifier:(nullable ASImageIdentifier)imageIdentifier;

/**
 * @abstract Notification that the image node finished displaying an image.
 * @param imageNode The sender.
 * @discussion This method is called every time an image is displayed, whether or not it has changed.
 */
- (void)multiplexImageNodeDidFinishDisplay:(ASMultiplexImageNode *)imageNode;

@end


#pragma mark -
/**
 * The ASMultiplexImageNodeDataSource protocol is adopted by an object that provides the multiplex image node,
 * for each image identifier, an image or a URL the image node should load.
 */
@protocol ASMultiplexImageNodeDataSource <NSObject>

@optional
/**
 * @abstract An image for the specified identifier.
 * @param imageNode The sender.
 * @param imageIdentifier The identifier for the image that should be returned.
 * @discussion If the image is already available to the data source, this method should be used in lieu of providing the
 * URL to the image via -multiplexImageNode:URLForImageIdentifier:.
 * @returns A UIImage corresponding to `imageIdentifier`, or nil if none is available.
 */
- (nullable UIImage *)multiplexImageNode:(ASMultiplexImageNode *)imageNode imageForImageIdentifier:(ASImageIdentifier)imageIdentifier;

/**
 * @abstract An image URL for the specified identifier.
 * @param imageNode The sender.
 * @param imageIdentifier The identifier for the image that will be downloaded.
 * @discussion Supported URLs include HTTP, HTTPS, AssetsLibrary, and FTP URLs as well as Photos framework URLs (see note).
 *
 * If the image is already available to the data source, it should be provided via <[ASMultiplexImageNodeDataSource
 * multiplexImageNode:imageForImageIdentifier:]> instead.
 * @return An NSURL for the image identified by `imageIdentifier`, or nil if none is available.
 * @see `+[NSURL URLWithAssetLocalIdentifier:targetSize:contentMode:options:]` below.
 */
- (nullable NSURL *)multiplexImageNode:(ASMultiplexImageNode *)imageNode URLForImageIdentifier:(ASImageIdentifier)imageIdentifier;

#if TARGET_OS_IOS
/**
 * @abstract A PHAsset for the specific asset local identifier
 * @param imageNode The sender.
 * @param assetLocalIdentifier The local identifier for a PHAsset that this image node is loading.
 *
 * @discussion This optional method can improve image performance if your data source already has the PHAsset available.
 * If this method is not implemented, or returns nil, the image node will request the asset from the Photos framework.
 * @note This method may be called from any thread.
 * @return A PHAsset corresponding to `assetLocalIdentifier`, or nil if none is available.
 */
- (nullable PHAsset *)multiplexImageNode:(ASMultiplexImageNode *)imageNode assetForLocalIdentifier:(NSString *)assetLocalIdentifier;
#endif
@end

#pragma mark - 
#if TARGET_OS_IOS
@interface NSURL (ASPhotosFrameworkURLs)

/**
 * @abstract Create an NSURL that specifies an image from the Photos framework.
 *
 * @discussion When implementing `-multiplexImageNode:URLForImageIdentifier:`, you can return a URL
 * created by this method and the image node will attempt to load the image from the Photos framework.
 * @note The `synchronous` flag in `options` is ignored.
 * @note The `Opportunistic` delivery mode is not supported and will be treated as `HighQualityFormat`.
 */
+ (NSURL *)URLWithAssetLocalIdentifier:(NSString *)assetLocalIdentifier
                            targetSize:(CGSize)targetSize
                           contentMode:(PHImageContentMode)contentMode
                               options:(PHImageRequestOptions *)options;

@end
#endif

NS_ASSUME_NONNULL_END

#endif
