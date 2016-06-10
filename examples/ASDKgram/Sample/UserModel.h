//
//  UserModel.h
//  Sample
//
//  Created by Hannah Troisi on 2/26/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

@interface UserModel : NSObject

@property (nonatomic, strong, readonly) NSDictionary *dictionaryRepresentation;
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