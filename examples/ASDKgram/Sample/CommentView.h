//
//  CommentView.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommentFeedModel.h"

@interface CommentView : UIView

+ (CGFloat)heightForCommentFeedModel:(CommentFeedModel *)feed withWidth:(CGFloat)width;

- (void)updateWithCommentFeedModel:(CommentFeedModel *)feed;

@end
