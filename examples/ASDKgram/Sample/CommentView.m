//
//  CommentView.m
//  Sample
//
//  Created by Hannah Troisi on 3/9/16.
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

#import "CommentView.h"
#import "PhotoFeedModel.h"
#import "Utilities.h"

#define INTER_COMMENT_SPACING 5
#define NUM_COMMENTS_TO_SHOW  3

@implementation CommentView
{
  CommentFeedModel           *_commentFeed;
  NSMutableArray <UILabel *> *_commentLabels;
}

#pragma mark - Class Methods

+ (CGFloat)heightForCommentFeedModel:(CommentFeedModel *)feed withWidth:(CGFloat)width
{
  NSAttributedString *string;
  CGRect rect;
  CGFloat height = 0;
  
  BOOL addViewAllCommentsLabel = [feed numberOfCommentsForPhotoExceedsInteger:NUM_COMMENTS_TO_SHOW];
  if (addViewAllCommentsLabel) {
    string  = [feed viewAllCommentsAttributedString];
    rect    = [string boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                                      options:NSStringDrawingUsesLineFragmentOrigin
                                                      context:nil];
    height += rect.size.height;
  }
  
  NSUInteger numCommentsInFeed = [feed numberOfItemsInFeed];

  for (int i = 0; i < numCommentsInFeed; i++) {
    
    string  = [[feed objectAtIndex:i] commentAttributedString];
    rect    = [string boundingRectWithSize:CGSizeMake(width, CGFLOAT_MAX)
                                   options:NSStringDrawingUsesLineFragmentOrigin
                                   context:nil];
    height += rect.size.height + INTER_COMMENT_SPACING;
  }

  return roundf(height);
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  if (self) {
    _commentLabels = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  CGSize boundsSize     = self.bounds.size;
  CGRect rect           = CGRectMake(0, 0, boundsSize.width, -INTER_COMMENT_SPACING);
  
  for (UILabel *commentsLabel in _commentLabels) {
    rect.origin.y       += rect.size.height + INTER_COMMENT_SPACING;
    rect.size           = [commentsLabel sizeThatFits:CGSizeMake(boundsSize.width, CGFLOAT_MAX)];
    commentsLabel.frame = rect;
  }
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
      [[_commentLabels objectAtIndex:labelsIndex] setAttributedText:commentLabelString];
      labelsIndex++;
    }
    
    NSUInteger numCommentsInFeed = [_commentFeed numberOfItemsInFeed];
    
    for (int feedIndex = 0; feedIndex < numCommentsInFeed; feedIndex++) {
      commentLabelString         = [[_commentFeed objectAtIndex:feedIndex] commentAttributedString];
      [[_commentLabels objectAtIndex:labelsIndex] setAttributedText:commentLabelString];
      labelsIndex++;
    }
    
    [self setNeedsLayout];
  }
}

#pragma mark - Helper Methods

- (void)removeCommentLabels
{
  for (UILabel *commentLabel in _commentLabels) {
    [commentLabel removeFromSuperview];
  }
  
  [_commentLabels removeAllObjects];
}

- (void)createCommentLabels
{
  BOOL addViewAllCommentsLabel = [_commentFeed numberOfCommentsForPhotoExceedsInteger:NUM_COMMENTS_TO_SHOW];
  NSUInteger numCommentsInFeed = [_commentFeed numberOfItemsInFeed];

  NSUInteger numLabelsToAdd    = (addViewAllCommentsLabel) ? numCommentsInFeed + 1 : numCommentsInFeed;
  
  for (NSUInteger i = 0; i < numLabelsToAdd; i++) {
    
    UILabel *commentLabel      = [[UILabel alloc] init];
    commentLabel.numberOfLines = 3;
    
    [_commentLabels addObject:commentLabel];
    [self addSubview:commentLabel];
  }
}

@end
