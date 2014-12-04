/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASImageNode.h>
#import <AsyncDisplayKit/ASImageProtocols.h>

@protocol ASNetworkImageNodeDelegate;


/**
 * ASNetworkImageNode is a simple image node that can download and display an image from the network, with support for a
 * placeholder image (<defaultImage>).  The currently-displayed image is always available in the inherited ASImageNode
 * <image> property.
 *
 * @see ASMultiplexImageNode for a more powerful counterpart to this class.
 */
@interface ASNetworkImageNode : ASImageNode

/**
 * The designated initializer.
 *
 * @param cache The object that implements a cache of images for the image node.
 * @param downloader The object that implements image downloading for the image node.  Must not be nil.
 *
 * @discussion If `cache` is nil, the receiver will not attempt to retrieve images from a cache before downloading them.
 *
 * @returns An initialized ASNetworkImageNode.
 */
- (instancetype)initWithCache:(id<ASImageCacheProtocol>)cache downloader:(id<ASImageDownloaderProtocol>)downloader;

/**
 * Convenience initialiser.
 *
 * @returns An ASNetworkImageNode configured to use the NSURLSession-powered ASBasicImageDownloader, and no extra cache.
 */
- (instancetype)init;

/**
 * The delegate, which must conform to the <ASNetworkImageNodeDelegate> protocol.
 */
@property (atomic, weak, readwrite) id<ASNetworkImageNodeDelegate> delegate;

/**
 * A placeholder image to display while the URL is loading.
 */
@property (atomic, strong, readwrite) UIImage *defaultImage;

/**
 * The URL of a new image to download and display.
 *
 * @discussion Changing this property will reset the displayed image to a placeholder (<defaultImage>) while loading.
 */
@property (atomic, strong, readwrite) NSURL *URL;

/**
 * Download and display a new image.
 *
 * @param reset Whether to display a placeholder (<defaultImage>) while loading the new image.
 */
- (void)setURL:(NSURL *)URL resetToDefault:(BOOL)reset;

/**
 * If <URL> is a local file, set this property to YES to take advantage of UIKit's image cacheing.  Defaults to YES.
 */
@property (nonatomic, assign, readwrite) BOOL shouldCacheImage;

@end


#pragma mark -
@protocol ASNetworkImageNodeDelegate <NSObject>

/**
 * Notification that the image node finished downloading an image.
 *
 * @param imageNode The sender.
 * @param image The newly-loaded image.
 *
 * @discussion Called on a background queue.
 */
- (void)imageNode:(ASNetworkImageNode *)imageNode didLoadImage:(UIImage *)image;

@optional

/**
 * Notification that the image node finished decoding an image.
 *
 * @param imageNode The sender.
 */
- (void)imageNodeDidFinishDecoding:(ASNetworkImageNode *)imageNode;

@end
