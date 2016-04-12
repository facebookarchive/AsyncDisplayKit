//
//  UserModel.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/26/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

@interface UserModel : NSObject

@property (nonatomic, assign, readonly) NSDictionary *dictionaryRepresentation;
@property (nonatomic, assign, readonly) NSUInteger   userID;
@property (nonatomic, strong, readonly) NSString     *username;
@property (nonatomic, strong, readonly) NSString     *firstName;
@property (nonatomic, strong, readonly) NSString     *lastName;
@property (nonatomic, strong, readonly) NSString     *fullName;
@property (nonatomic, strong, readonly) NSString     *city;
@property (nonatomic, strong, readonly) NSString     *state;
@property (nonatomic, strong, readonly) NSString     *country;
@property (nonatomic, strong, readonly) NSString     *about;
@property (nonatomic, strong, readonly) NSString     *domain;
@property (nonatomic, strong, readonly) NSURL        *userPicURL;
@property (nonatomic, assign, readonly) NSUInteger   photoCount;
@property (nonatomic, assign, readonly) NSUInteger   galleriesCount;
@property (nonatomic, assign, readonly) NSUInteger   affection;
@property (nonatomic, assign, readonly) NSUInteger   friendsCount;
@property (nonatomic, assign, readonly) NSUInteger   followersCount;
@property (nonatomic, assign, readonly) BOOL         following;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWith500pxPhoto:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size;
- (NSAttributedString *)fullNameAttributedStringWithFontSize:(CGFloat)size;

- (void)fetchAvatarImageWithCompletionBlock:(void(^)(UserModel *, UIImage *))block;

- (void)downloadCompleteUserDataWithCompletionBlock:(void(^)(UserModel *))block;

@end