//
//  ASPhotosFrameworkImageRequest.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/25/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

// NS_ASSUME_NONNULL_BEGIN

extern NSString *const ASPhotosURLScheme;

/**
 @abstract Use ASPhotosFrameworkImageRequest to encapsulate all the information needed to request an image from
 the Photos framework and store it in a URL.
 */
@interface ASPhotosFrameworkImageRequest : NSObject <NSCopying>

- (instancetype)initWithAssetIdentifier:(NSString *)assetIdentifier NS_DESIGNATED_INITIALIZER;

/**
 @return A new image request deserialized from `url`, or nil if `url` is not a valid photos URL.
 */
+ (/*nullable*/ ASPhotosFrameworkImageRequest *)requestWithURL:(NSURL *)url;

/**
 @abstract The asset identifier for this image request provided during initialization.
 */
@property (nonatomic, readonly) NSString *assetIdentifier;

/**
 @abstract The target size for this image request. Defaults to `PHImageManagerMaximumSize`.
 */
@property (nonatomic) CGSize targetSize;

/**
 @abstract The content mode for this image request. Defaults to `PHImageContentModeDefault`.
 
 @see `PHImageManager`
 */
@property (nonatomic) PHImageContentMode contentMode;

/**
 @abstract The options specified for this request. Default value is the result of `[PHImageRequestOptions new]`.
 
 @discussion Some properties of this object are ignored when converting this request into a URL.
 As of iOS SDK 9.0, these properties are `progressHandler` and `synchronous`.
 */
@property (nonatomic, strong) PHImageRequestOptions *options;

/**
 @return A new URL converted from this request.
 */
@property (nonatomic, readonly) NSURL *url;

/**
 @return `YES` if `object` is an equivalent image request, `NO` otherwise.
 */
- (BOOL)isEqual:(id)object;

@end

// NS_ASSUME_NONNULL_END
