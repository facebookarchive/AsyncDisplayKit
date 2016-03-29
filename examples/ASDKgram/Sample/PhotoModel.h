//
//  PhotoModel.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/26/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
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
