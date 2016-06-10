//
//  PhotoFeedModel.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 2/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "PhotoModel.h"

typedef NS_ENUM(NSInteger, PhotoFeedModelType) {
  PhotoFeedModelTypePopular,
  PhotoFeedModelTypeLocation,
  PhotoFeedModelTypeUserPhotos
};

@interface PhotoFeedModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPhotoFeedModelType:(PhotoFeedModelType)type imageSize:(CGSize)size NS_DESIGNATED_INITIALIZER;

- (NSUInteger)totalNumberOfPhotos;
- (NSUInteger)numberOfItemsInFeed;
- (PhotoModel *)objectAtIndex:(NSUInteger)index;
- (NSInteger)indexOfPhotoModel:(PhotoModel *)photoModel;

- (void)updatePhotoFeedModelTypeLocationCoordinates:(CLLocationCoordinate2D)coordinate radiusInMiles:(NSUInteger)radius;
- (void)updatePhotoFeedModelTypeUserId:(NSUInteger)userID;

- (void)clearFeed;
- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults;
- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block numResultsToReturn:(NSUInteger)numResults;

@end
