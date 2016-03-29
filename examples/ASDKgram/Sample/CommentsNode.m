//
//  CommentsNode.m
//  ASDKgram
//
//  Created by Hannah Troisi on 3/21/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "CommentsNode.h"

#define INTER_COMMENT_SPACING 5
#define NUM_COMMENTS_TO_SHOW 3

@implementation CommentsNode
{
  CommentFeedModel              *_commentFeed;
  NSMutableArray <ASTextNode *> *_commentNodes;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _commentNodes = [[NSMutableArray alloc] init];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *verticalStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.spacing            = INTER_COMMENT_SPACING;
  [verticalStack setChildren:_commentNodes];
  
  return verticalStack;
}

#pragma mark - Instance Methods

- (void)updateWithCommentFeedModel:(CommentFeedModel *)feed
{
  _commentFeed = feed;
  [self removeCommentLabels];
  
  if (_commentFeed) {
    [self createCommentLabels];
    
    BOOL addViewAllCommentsLabel = [feed numberOfCommentsForPhotoExceedsInteger:NUM_COMMENTS_TO_SHOW];
    NSAttributedString *commentLabelString;
    int labelsIndex = 0;
    
    if (addViewAllCommentsLabel) {
      commentLabelString        = [_commentFeed viewAllCommentsAttributedString];
      [[_commentNodes objectAtIndex:labelsIndex] setAttributedString:commentLabelString];
      labelsIndex++;
    }
    
    NSUInteger numCommentsInFeed = [_commentFeed numberOfItemsInFeed];
    
    for (int feedIndex = 0; feedIndex < numCommentsInFeed; feedIndex++) {
      commentLabelString         = [[_commentFeed objectAtIndex:feedIndex] commentAttributedString];
      [[_commentNodes objectAtIndex:labelsIndex] setAttributedString:commentLabelString];
      labelsIndex++;
    }
    
    [self setNeedsLayout];
  }
}


#pragma mark - Helper Methods

- (void)removeCommentLabels
{
  for (ASTextNode *commentLabel in _commentNodes) {
    [commentLabel removeFromSupernode];
  }
  
  [_commentNodes removeAllObjects];
}

- (void)createCommentLabels
{
  BOOL addViewAllCommentsLabel = [_commentFeed numberOfCommentsForPhotoExceedsInteger:NUM_COMMENTS_TO_SHOW];
  NSUInteger numCommentsInFeed = [_commentFeed numberOfItemsInFeed];
  
  NSUInteger numLabelsToAdd    = (addViewAllCommentsLabel) ? numCommentsInFeed + 1 : numCommentsInFeed;
  
  for (NSUInteger i = 0; i < numLabelsToAdd; i++) {
    
    ASTextNode *commentLabel      = [[ASTextNode alloc] init];
    commentLabel.maximumNumberOfLines = 3;
    
    [_commentNodes addObject:commentLabel];
    [self addSubnode:commentLabel];
  }
}

@end
