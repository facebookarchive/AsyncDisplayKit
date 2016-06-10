//
//  CommentsNode.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/21/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "CommentFeedModel.h"

@interface CommentsNode : ASTextCellNode

- (void)updateWithCommentFeedModel:(CommentFeedModel *)feed;

@end
