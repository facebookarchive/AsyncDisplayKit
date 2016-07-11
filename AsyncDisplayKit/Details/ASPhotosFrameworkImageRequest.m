//
//  ASPhotosFrameworkImageRequest.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/25/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
#if TARGET_OS_IOS
#import "ASPhotosFrameworkImageRequest.h"
#import "ASBaseDefines.h"
#import "ASAvailability.h"

NSString *const ASPhotosURLScheme = @"ph";

static NSString *const _ASPhotosURLQueryKeyWidth = @"width";
static NSString *const _ASPhotosURLQueryKeyHeight = @"height";

// value is PHImageContentMode value
static NSString *const _ASPhotosURLQueryKeyContentMode = @"contentmode";

// value is PHImageRequestOptionsResizeMode value
static NSString *const _ASPhotosURLQueryKeyResizeMode = @"resizemode";

// value is PHImageRequestOptionsDeliveryMode value
static NSString *const _ASPhotosURLQueryKeyDeliveryMode = @"deliverymode";

// value is PHImageRequestOptionsVersion value
static NSString *const _ASPhotosURLQueryKeyVersion = @"version";

// value is 0 or 1
static NSString *const _ASPhotosURLQueryKeyAllowNetworkAccess = @"network";

static NSString *const _ASPhotosURLQueryKeyCropOriginX = @"crop_x";
static NSString *const _ASPhotosURLQueryKeyCropOriginY = @"crop_y";
static NSString *const _ASPhotosURLQueryKeyCropWidth = @"crop_w";
static NSString *const _ASPhotosURLQueryKeyCropHeight = @"crop_h";

@implementation ASPhotosFrameworkImageRequest

- (instancetype)init
{
  ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
  self = [self initWithAssetIdentifier:@""];
  return nil;
}

- (instancetype)initWithAssetIdentifier:(NSString *)assetIdentifier
{
  self = [super init];
  if (self) {
    _assetIdentifier = assetIdentifier;
    _options = [PHImageRequestOptions new];
    _contentMode = PHImageContentModeDefault;
    _targetSize = PHImageManagerMaximumSize;
  }
  return self;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
  ASPhotosFrameworkImageRequest *copy = [[ASPhotosFrameworkImageRequest alloc] initWithAssetIdentifier:self.assetIdentifier];
  copy.options = [self.options copy];
  copy.targetSize = self.targetSize;
  copy.contentMode = self.contentMode;
  return copy;
}

#pragma mark Converting to URL

- (NSURL *)url
{
  NSURLComponents *comp = [NSURLComponents new];
  comp.scheme = ASPhotosURLScheme;
  comp.host = _assetIdentifier;
  NSMutableArray *queryItems = [NSMutableArray arrayWithObjects:
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyWidth value:@(_targetSize.width).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyHeight value:@(_targetSize.height).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyVersion value:@(_options.version).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyContentMode value:@(_contentMode).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyAllowNetworkAccess value:@(_options.networkAccessAllowed).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyResizeMode value:@(_options.resizeMode).stringValue],
    [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyDeliveryMode value:@(_options.deliveryMode).stringValue]
  , nil];
  
  CGRect cropRect = _options.normalizedCropRect;
  if (!CGRectIsEmpty(cropRect)) {
    [queryItems addObjectsFromArray:@[
      [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyCropOriginX value:@(cropRect.origin.x).stringValue],
      [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyCropOriginY value:@(cropRect.origin.y).stringValue],
      [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyCropWidth value:@(cropRect.size.width).stringValue],
      [NSURLQueryItem queryItemWithName:_ASPhotosURLQueryKeyCropHeight value:@(cropRect.size.height).stringValue]
    ]];
  }
  comp.queryItems = queryItems;
  return comp.URL;
}

#pragma mark Converting from URL

+ (ASPhotosFrameworkImageRequest *)requestWithURL:(NSURL *)url
{
  // not a photos URL or iOS < 8
  if (![url.scheme isEqualToString:ASPhotosURLScheme] || !AS_AT_LEAST_IOS8) {
    return nil;
  }
  
  NSURLComponents *comp = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  
  ASPhotosFrameworkImageRequest *request = [[ASPhotosFrameworkImageRequest alloc] initWithAssetIdentifier:url.host];
  
  CGRect cropRect = CGRectZero;
  CGSize targetSize = PHImageManagerMaximumSize;
  for (NSURLQueryItem *item in comp.queryItems) {
    if ([_ASPhotosURLQueryKeyAllowNetworkAccess isEqualToString:item.name]) {
      request.options.networkAccessAllowed = item.value.boolValue;
    } else if ([_ASPhotosURLQueryKeyWidth isEqualToString:item.name]) {
      targetSize.width = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyHeight isEqualToString:item.name]) {
      targetSize.height = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyContentMode isEqualToString:item.name]) {
      request.contentMode = (PHImageContentMode)item.value.integerValue;
    } else if ([_ASPhotosURLQueryKeyVersion isEqualToString:item.name]) {
      request.options.version = (PHImageRequestOptionsVersion)item.value.integerValue;
    } else if ([_ASPhotosURLQueryKeyCropOriginX isEqualToString:item.name]) {
      cropRect.origin.x = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyCropOriginY isEqualToString:item.name]) {
      cropRect.origin.y = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyCropWidth isEqualToString:item.name]) {
      cropRect.size.width = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyCropHeight isEqualToString:item.name]) {
      cropRect.size.height = item.value.doubleValue;
    } else if ([_ASPhotosURLQueryKeyResizeMode isEqualToString:item.name]) {
      request.options.resizeMode = (PHImageRequestOptionsResizeMode)item.value.integerValue;
    } else if ([_ASPhotosURLQueryKeyDeliveryMode isEqualToString:item.name]) {
      request.options.deliveryMode = (PHImageRequestOptionsDeliveryMode)item.value.integerValue;
    }
  }
  request.targetSize = targetSize;
  request.options.normalizedCropRect = cropRect;
  return request;
}

#pragma mark NSObject

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:ASPhotosFrameworkImageRequest.class]) {
    return NO;
  }
  ASPhotosFrameworkImageRequest *other = object;
  return [other.assetIdentifier isEqualToString:self.assetIdentifier] &&
    other.contentMode == self.contentMode &&
    CGSizeEqualToSize(other.targetSize, self.targetSize) &&
    CGRectEqualToRect(other.options.normalizedCropRect, self.options.normalizedCropRect) &&
    other.options.resizeMode == self.options.resizeMode &&
    other.options.version == self.options.version;
}

@end
#endif