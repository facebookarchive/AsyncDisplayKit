//
//  PhotoModel.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 2/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "CoreGraphics/CoreGraphics.h"
#import "UserModel.h"
#import "LocationModel.h"
#import "CommentFeedModel.h"

@interface PhotoModel : NSObject

@property (nonatomic, strong, readonly) NSURL                  *URL;
@property (nonatomic, strong, readonly) NSString               *photoID;
@property (nonatomic, strong, readonly) NSString               *uploadDateString;
@property (nonatomic, strong, readonly) NSString               *title;
@property (nonatomic, strong, readonly) NSString               *descriptionText;
@property (nonatomic, assign, readonly) NSUInteger             commentsCount;
@property (nonatomic, assign, readonly) NSUInteger             likesCount;
@property (nonatomic, strong, readonly) LocationModel          *location;
@property (nonatomic, strong, readonly) UserModel              *ownerUserProfile;
@property (nonatomic, strong, readonly) CommentFeedModel       *commentFeed;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWith500pxPhoto:(NSDictionary *)photoDictionary NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size;

@end
