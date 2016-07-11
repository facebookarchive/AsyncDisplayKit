//
//  PhotoTableViewCell.m
//  Sample
//
//  Created by Hannah Troisi on 2/17/16.
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

#import "PhotoTableViewCell.h"
#import "Utilities.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"
#import "CommentView.h"

#define DEBUG_PHOTOCELL_LAYOUT  0
#define USE_UIKIT_AUTOLAYOUT    1
#define USE_UIKIT_MANUAL_LAYOUT !USE_UIKIT_AUTOLAYOUT

#define HEADER_HEIGHT           50
#define USER_IMAGE_HEIGHT       30
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               14

@implementation PhotoTableViewCell
{
  PhotoModel   *_photoModel;
  CommentView  *_photoCommentsView;
  
  UIImageView  *_userAvatarImageView;
  UIImageView  *_photoImageView;
  UILabel      *_userNameLabel;
  UILabel      *_photoLocationLabel;
  UILabel      *_photoTimeIntervalSincePostLabel;
  UILabel      *_photoLikesLabel;
  UILabel      *_photoDescriptionLabel;
  
  NSLayoutConstraint *_userNameYPositionWithPhotoLocation;
  NSLayoutConstraint *_userNameYPositionWithoutPhotoLocation;
  NSLayoutConstraint *_photoLocationYPosition;
}

#pragma mark - Class Methods

+ (CGFloat)heightForPhotoModel:(PhotoModel *)photo withWidth:(CGFloat)width;
{
  CGFloat photoHeight = width;
  
  UIFont *font        = [UIFont systemFontOfSize:FONT_SIZE];
  CGFloat likesHeight = roundf([font lineHeight]);
  
  NSAttributedString *descriptionAttrString = [photo descriptionAttributedStringWithFontSize:FONT_SIZE];
  CGFloat availableWidth                    = (width - HORIZONTAL_BUFFER * 2);
  CGFloat descriptionHeight                 = [descriptionAttrString boundingRectWithSize:CGSizeMake(availableWidth, CGFLOAT_MAX)
                                                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                                                                  context:nil].size.height;
  
  CGFloat commentViewHeight = [CommentView heightForCommentFeedModel:photo.commentFeed withWidth:availableWidth];
  
  return HEADER_HEIGHT + photoHeight + likesHeight + descriptionHeight + commentViewHeight + (4 * VERTICAL_BUFFER);
}

#pragma mark - Lifecycle

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  
  if (self) {
    
    _photoCommentsView                   = [[CommentView alloc] init];
    _userAvatarImageView                 = [[UIImageView alloc] init];
    _photoImageView                      = [[UIImageView alloc] init];
    _userNameLabel                       = [[UILabel alloc] init];
    _photoLocationLabel                  = [[UILabel alloc] init];
    _photoTimeIntervalSincePostLabel     = [[UILabel alloc] init];
    _photoLikesLabel                     = [[UILabel alloc] init];
    _photoDescriptionLabel               = [[UILabel alloc] init];
    _photoDescriptionLabel.numberOfLines = 3;

    [self addSubview:_photoCommentsView];
    [self addSubview:_userAvatarImageView];
    [self addSubview:_photoImageView];
    [self addSubview:_userNameLabel];
    [self addSubview:_photoLocationLabel];
    [self addSubview:_photoTimeIntervalSincePostLabel];
    [self addSubview:_photoLikesLabel];
    [self addSubview:_photoDescriptionLabel];

#if USE_UIKIT_AUTOLAYOUT
    [_photoCommentsView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_userAvatarImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoImageView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_userNameLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoLocationLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoTimeIntervalSincePostLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoLikesLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoDescriptionLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_photoCommentsView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    [self setupConstraints];
    [self updateConstraints];
#endif
    
#if DEBUG_PHOTOCELL_LAYOUT
    _userAvatarImageView.backgroundColor              = [UIColor greenColor];
    _userNameLabel.backgroundColor                    = [UIColor greenColor];
    _photoLocationLabel.backgroundColor               = [UIColor greenColor];
    _photoTimeIntervalSincePostLabel.backgroundColor  = [UIColor greenColor];
    _photoCommentsView.backgroundColor                = [UIColor greenColor];
    _photoDescriptionLabel.backgroundColor            = [UIColor greenColor];
    _photoLikesLabel.backgroundColor                  = [UIColor greenColor];
#endif
  }
  
  return self;
}

-(void)setFrame:(CGRect)frame
{
  [super setFrame:frame];
}

- (void)setupConstraints
{
  // _userAvatarImageView
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView.superview
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView.superview
                                                   attribute:NSLayoutAttributeTop
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:nil
                                                   attribute:NSLayoutAttributeNotAnAttribute
                                                  multiplier:0.0
                                                    constant:USER_IMAGE_HEIGHT]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeHeight
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:0.0]];
  
  // _userNameLabel
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userNameLabel
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeRight
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_userNameLabel
                                                   attribute:NSLayoutAttributeRight
                                                   relatedBy:NSLayoutRelationLessThanOrEqual
                                                      toItem:_photoTimeIntervalSincePostLabel
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:-HORIZONTAL_BUFFER]];
  
  _userNameYPositionWithoutPhotoLocation = [NSLayoutConstraint constraintWithItem:_userNameLabel
                                                                        attribute:NSLayoutAttributeCenterY
                                                                        relatedBy:NSLayoutRelationEqual
                                                                           toItem:_userAvatarImageView
                                                                        attribute:NSLayoutAttributeCenterY
                                                                       multiplier:1.0
                                                                         constant:0.0];
  [self addConstraint:_userNameYPositionWithoutPhotoLocation];
  
  _userNameYPositionWithPhotoLocation = [NSLayoutConstraint constraintWithItem:_userNameLabel
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:_userAvatarImageView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:-2];
  _userNameYPositionWithPhotoLocation.active = NO;
  [self addConstraint:_userNameYPositionWithPhotoLocation];
  
  // _photoLocationLabel
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoLocationLabel
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeRight
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoLocationLabel
                                                   attribute:NSLayoutAttributeRight
                                                   relatedBy:NSLayoutRelationLessThanOrEqual
                                                      toItem:_photoTimeIntervalSincePostLabel
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:-HORIZONTAL_BUFFER]];
  
  _photoLocationYPosition = [NSLayoutConstraint constraintWithItem:_photoLocationLabel
                                                         attribute:NSLayoutAttributeBottom
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:_userAvatarImageView
                                                         attribute:NSLayoutAttributeBottom
                                                        multiplier:1.0
                                                          constant:2];
  _photoLocationYPosition.active = NO;
  [self addConstraint:_photoLocationYPosition];
  
  // _photoTimeIntervalSincePostLabel
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoTimeIntervalSincePostLabel
                                                   attribute:NSLayoutAttributeRight
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoTimeIntervalSincePostLabel.superview
                                                   attribute:NSLayoutAttributeRight
                                                  multiplier:1.0
                                                    constant:-HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoTimeIntervalSincePostLabel
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_userAvatarImageView
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1.0
                                                    constant:0.0]];
  
  // _photoImageView
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoImageView
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoImageView.superview
                                                   attribute:NSLayoutAttributeTop
                                                  multiplier:1.0
                                                    constant:HEADER_HEIGHT]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoImageView
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:0.0]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoImageView
                                                   attribute:NSLayoutAttributeHeight
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoImageView
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:0.0]];
  
  // _photoLikesLabel
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoLikesLabel
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoImageView
                                                   attribute:NSLayoutAttributeBottom
                                                  multiplier:1.0
                                                    constant:VERTICAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoLikesLabel
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoLikesLabel.superview
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  // _photoDescriptionLabel
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoDescriptionLabel
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoLikesLabel
                                                   attribute:NSLayoutAttributeBottom
                                                  multiplier:1.0
                                                    constant:VERTICAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoDescriptionLabel
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoDescriptionLabel.superview
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoDescriptionLabel
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoDescriptionLabel.superview
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:-HORIZONTAL_BUFFER]];
  
  // _photoCommentsView
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoCommentsView
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoDescriptionLabel
                                                   attribute:NSLayoutAttributeBottom
                                                  multiplier:1.0
                                                    constant:VERTICAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoCommentsView
                                                   attribute:NSLayoutAttributeLeft
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoCommentsView.superview
                                                   attribute:NSLayoutAttributeLeft
                                                  multiplier:1.0
                                                    constant:HORIZONTAL_BUFFER]];
  
  [self addConstraint:[NSLayoutConstraint constraintWithItem:_photoCommentsView
                                                   attribute:NSLayoutAttributeWidth
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:_photoCommentsView.superview
                                                   attribute:NSLayoutAttributeWidth
                                                  multiplier:1.0
                                                    constant:-HORIZONTAL_BUFFER]];
}

- (void)updateConstraints
{
  [super updateConstraints];
  
  if (_photoLocationLabel.attributedText) {
    _userNameYPositionWithoutPhotoLocation.active = NO;
    _userNameYPositionWithPhotoLocation.active = YES;
    _photoLocationYPosition.active = YES;
  } else {
    _userNameYPositionWithoutPhotoLocation.active = YES;
    _userNameYPositionWithPhotoLocation.active = NO;
    _photoLocationYPosition.active = NO;
  }
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
#if USE_UIKIT_PROGRAMMATIC_LAYOUT
  CGSize boundsSize = self.bounds.size;
  
  CGRect rect = CGRectMake(HORIZONTAL_BUFFER, (HEADER_HEIGHT - USER_IMAGE_HEIGHT) / 2.0,
                           USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
  _userAvatarImageView.frame = rect;

  rect.size = _photoTimeIntervalSincePostLabel.bounds.size;
  rect.origin.x = boundsSize.width - HORIZONTAL_BUFFER - rect.size.width;
  rect.origin.y = (HEADER_HEIGHT - rect.size.height) / 2.0;
  _photoTimeIntervalSincePostLabel.frame = rect;

  CGFloat availableWidth = CGRectGetMinX(_photoTimeIntervalSincePostLabel.frame) - HORIZONTAL_BUFFER;
  rect.size = _userNameLabel.bounds.size;
  rect.size.width = MIN(availableWidth, rect.size.width);

  rect.origin.x = HORIZONTAL_BUFFER + USER_IMAGE_HEIGHT + HORIZONTAL_BUFFER;
  
  if (_photoLocationLabel.attributedText) {
    CGSize locationSize = _photoLocationLabel.bounds.size;
    locationSize.width = MIN(availableWidth, locationSize.width);
    
    rect.origin.y = (HEADER_HEIGHT - rect.size.height - locationSize.height) / 2.0;
    _userNameLabel.frame = rect;
    
    // FIXME: Name rects at least for this sub-condition
    rect.origin.y += rect.size.height;
    rect.size = locationSize;
    _photoLocationLabel.frame = rect;
  } else {
    rect.origin.y = (HEADER_HEIGHT - rect.size.height) / 2.0;
    _userNameLabel.frame = rect;
  }

  _photoImageView.frame = CGRectMake(0, HEADER_HEIGHT, boundsSize.width, boundsSize.width);
  
  // FIXME: Make PhotoCellFooterView
  rect.size = _photoLikesLabel.bounds.size;
  rect.origin = CGPointMake(HORIZONTAL_BUFFER, CGRectGetMaxY(_photoImageView.frame) + VERTICAL_BUFFER);
  _photoLikesLabel.frame = rect;

  rect.size = _photoDescriptionLabel.bounds.size;
  rect.size.width = MIN(boundsSize.width - HORIZONTAL_BUFFER * 2, rect.size.width);
  rect.origin.y = CGRectGetMaxY(_photoLikesLabel.frame) + VERTICAL_BUFFER;
  _photoDescriptionLabel.frame = rect;

  rect.size = _photoCommentsView.bounds.size;
  rect.size.width = boundsSize.width - HORIZONTAL_BUFFER * 2;
  rect.origin.y = CGRectGetMaxY(_photoDescriptionLabel.frame) + VERTICAL_BUFFER;
  _photoCommentsView.frame = rect;
#endif
}

- (void)prepareForReuse
{
  [super prepareForReuse];
  
  _photoCommentsView.frame                        = CGRectZero;   // next cell might not have a _photoCommentsView
  [_photoCommentsView updateWithCommentFeedModel:nil];
  
  _userAvatarImageView.image                      = nil;
  _photoImageView.image                           = nil;
  _userNameLabel.attributedText                   = nil;
  _photoLocationLabel.attributedText              = nil;
  _photoLocationLabel.frame                       = CGRectZero;   // next cell might not have a _photoLocationLabel
  _photoTimeIntervalSincePostLabel.attributedText = nil;
  _photoLikesLabel.attributedText                 = nil;
  _photoDescriptionLabel.attributedText           = nil;
}

#pragma mark - Instance Methods

- (void)updateCellWithPhotoObject:(PhotoModel *)photo
{
  _photoModel                                     = photo;
  _userNameLabel.attributedText                   = [photo.ownerUserProfile usernameAttributedStringWithFontSize:FONT_SIZE];
  _photoTimeIntervalSincePostLabel.attributedText = [photo uploadDateAttributedStringWithFontSize:FONT_SIZE];
  _photoLikesLabel.attributedText                 = [photo likesAttributedStringWithFontSize:FONT_SIZE];
  _photoDescriptionLabel.attributedText           = [photo descriptionAttributedStringWithFontSize:FONT_SIZE];
  
  [_userNameLabel sizeToFit];
  [_photoTimeIntervalSincePostLabel sizeToFit];
  [_photoLikesLabel sizeToFit];
  [_photoDescriptionLabel sizeToFit];
  CGRect rect                  = _photoDescriptionLabel.frame;
  CGFloat availableWidth       = (self.bounds.size.width - HORIZONTAL_BUFFER * 2);
  rect.size                    = [_photoDescriptionLabel sizeThatFits:CGSizeMake(availableWidth, CGFLOAT_MAX)];
  _photoDescriptionLabel.frame = rect;

  [UIImage downloadImageForURL:photo.URL completion:^(UIImage *image) {
    _photoImageView.image = image;
  }];
  
  [self downloadAndProcessUserAvatarForPhoto:photo];
  [self loadCommentsForPhoto:photo];
  [self reverseGeocodeLocationForPhoto:photo];
}

- (void)loadCommentsForPhoto:(PhotoModel *)photo
{
  if (photo.commentFeed.numberOfItemsInFeed > 0) {
    [_photoCommentsView updateWithCommentFeedModel:photo.commentFeed];
    
    CGRect frame             = _photoCommentsView.frame;
    CGFloat availableWidth   = (self.bounds.size.width - HORIZONTAL_BUFFER * 2);
    frame.size.width         = availableWidth;
    frame.size.height        = [CommentView heightForCommentFeedModel:photo.commentFeed withWidth:availableWidth];
    _photoCommentsView.frame = frame;
    
    [self setNeedsLayout];
  }
}

#pragma mark - Helper Methods

- (void)downloadAndProcessUserAvatarForPhoto:(PhotoModel *)photo
{
  [UIImage downloadImageForURL:photo.URL completion:^(UIImage *image) {
    CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
    _userAvatarImageView.image = [image makeCircularImageWithSize:profileImageSize];
  }];
}

- (void)reverseGeocodeLocationForPhoto:(PhotoModel *)photo
{
  [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
    
    // check and make sure this is still relevant for this cell (and not an old cell)
    // make sure to use _photoModel instance variable as photo may change when cell is reused,
    // where as local variable will never change
    if (locationModel == _photoModel.location) {
      _photoLocationLabel.attributedText = [photo locationAttributedStringWithFontSize:FONT_SIZE];
      [_photoLocationLabel sizeToFit];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [self updateConstraints];
        [self setNeedsLayout];
      });
    }
  }];
}

@end
