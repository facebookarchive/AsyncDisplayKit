//
//  PhotoTableViewCell.m
//  ASDKgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoTableViewCell.h"
#import "Utilities.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"
#import "CommentView.h"

#define DEBUG_PHOTOCELL_LAYOUT  0

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

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  CGSize boundsSize = self.bounds.size;
  
  // FIXME: Make PhotoCellHeaderView
  
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

  [[PINRemoteImageManager sharedImageManager] downloadImageWithURL:photo.URL
                                                           options:PINRemoteImageManagerDownloadOptionsSkipDecode
                                                        completion:^(PINRemoteImageManagerResult * _Nonnull result) {
                                                          _photoImageView.image = result.image;
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
  [[PINRemoteImageManager sharedImageManager] downloadImageWithURL:_photoModel.ownerUserProfile.userPicURL
                                                           options:PINRemoteImageManagerDownloadOptionsSkipDecode
                                                      processorKey:@"custom"
                                                         processor:^UIImage * _Nullable(PINRemoteImageManagerResult * _Nonnull result, NSUInteger * _Nonnull cost) {
                                                           CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
                                                           return [result.image makeCircularImageWithSize:profileImageSize];
                                                         } completion:^(PINRemoteImageManagerResult * _Nonnull result) {
                                                           _userAvatarImageView.image = result.image;
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
      [self setNeedsLayout];
    }
  }];
}

@end
