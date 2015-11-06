//
//  PostNode.h
//  Sample
//
//  Created by Vitaly Baev on 06.11.15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "Post.h"

@class LikesNode;
@class CommentsNode;

@interface PostNode : ASCellNode <ASTextNodeDelegate> {
    
    Post *_post;
    
    ASDisplayNode *_divider;
    ASTextNode *_nameNode;
    ASTextNode *_usernameNode;
    ASTextNode *_timeNode;
    ASTextNode *_postNode;
    ASImageNode *_viaNode;
    ASNetworkImageNode *_avatarNode;
    ASNetworkImageNode *_mediaNode;
    LikesNode *_likesNode;
    CommentsNode *_commentsNode;
    ASImageNode *_optionsNode;
    
}

- (instancetype)initWithPost:(Post *)post;

@end
