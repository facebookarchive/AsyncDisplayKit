//
//  CommentModel.h
//  ASDKgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CommentModel : NSObject

@property (nonatomic, assign, readonly) NSUInteger             ID;
@property (nonatomic, assign, readonly) NSUInteger             commenterID;
@property (nonatomic, strong, readonly) NSString               *commenterUsername;
@property (nonatomic, strong, readonly) NSString               *commenterAvatarURL;
@property (nonatomic, strong, readonly) NSString               *body;
@property (nonatomic, strong, readonly) NSString               *uploadDateString;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithDictionary:(NSDictionary *)photoDictionary NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)commentAttributedString;
- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size;

@end
