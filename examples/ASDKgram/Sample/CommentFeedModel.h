//
//  CommentFeedModel.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CommentModel.h"

@interface CommentFeedModel : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPhotoID:(NSString *)photoID NS_DESIGNATED_INITIALIZER;

- (NSUInteger)numberOfItemsInFeed;
- (CommentModel *)objectAtIndex:(NSUInteger)index;

- (NSUInteger)numberOfCommentsForPhoto;
- (BOOL)numberOfCommentsForPhotoExceedsInteger:(NSUInteger)number;
- (NSAttributedString *)viewAllCommentsAttributedString;

- (void)requestPageWithCompletionBlock:(void (^)(NSArray *))block;
- (void)refreshFeedWithCompletionBlock:(void (^)(NSArray *))block;

@end
