//
//  UserRowView.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/13/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserModel.h"
#import "PhotoModel.h"


typedef NS_ENUM(NSInteger, UserRowViewType) {
  UserRowViewTypeLikes,
  UserRowViewTypeComments,
  UserRowViewTypePhotoCell
};

@interface UserRowView : UIView

+ (CGFloat)heightForUserRowViewType:(UserRowViewType)type;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame withPhotoFeedModelType:(UserRowViewType)type NS_DESIGNATED_INITIALIZER;

- (void)updateWithPhotoModel:(PhotoModel *)photo;
- (void)updateWithCommentModel:(CommentModel *)comment;

@end
