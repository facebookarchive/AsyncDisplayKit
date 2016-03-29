//
//  UserRowView.m
//  ASDKgram
//
//  Created by Hannah Troisi on 3/13/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "UserRowView.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"
#import "Utilities.h"

#define LIKES_VIEW_HEIGHT       50
#define LIKES_IMAGE_HEIGHT      30

#define PHOTOCELL_VIEW_HEIGHT   50
#define PHOTOCELL_IMAGE_HEIGHT  30

#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               14

#define FOLLOW_BUTTON_CORNER_RADIUS 8

@implementation UserRowView
{
  UserRowViewType _viewType;
  PhotoModel      *_photo;
  CommentModel    *_comment;
  UIImageView     *_userAvatarImageView;
  UIButton        *_followingStatusBtn;
  UILabel         *_userNameLabel;
  UILabel         *_detailLabel;                     // configurable to be location, comment, full name
  UILabel         *_photoTimeIntervalSincePostLabel;
}

#pragma mark - Class Methods

+ (CGFloat)heightForUserRowViewType:(UserRowViewType)type
{
  if (type && UserRowViewTypeLikes) {
    return LIKES_VIEW_HEIGHT;
  } else {
    return LIKES_IMAGE_HEIGHT;
  }
}


#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame withPhotoFeedModelType:(UserRowViewType)type
{
  self = [super initWithFrame:frame];
  
  if (self) {
    
    _viewType            = type;
    _userAvatarImageView = [[UIImageView alloc] init];
    [_userAvatarImageView setPin_updateWithProgress:YES];
    _userNameLabel       = [[UILabel alloc] init];
    _detailLabel         = [[UILabel alloc] init];
    [self addSubview:_userAvatarImageView];
    [self addSubview:_userNameLabel];
    [self addSubview:_detailLabel];
    
    if (type == UserRowViewTypeLikes) {
      
      _followingStatusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
      [self addSubview:_followingStatusBtn];
      
      UIImage *followingImage = [UIImage followingButtonStretchableImageForCornerRadius:FOLLOW_BUTTON_CORNER_RADIUS following:YES];
      UIImage *notFollowingImage = [UIImage followingButtonStretchableImageForCornerRadius:FOLLOW_BUTTON_CORNER_RADIUS following:NO];
      [_followingStatusBtn setBackgroundImage:followingImage forState:UIControlStateSelected];
      [_followingStatusBtn setBackgroundImage:notFollowingImage forState:UIControlStateNormal];
      
    } else {
      
      _photoTimeIntervalSincePostLabel = [[UILabel alloc] init];
      [self addSubview:_photoTimeIntervalSincePostLabel];
    }
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  CGSize  boundsSize     = self.bounds.size;
  CGFloat viewHeight     = (_viewType && UserRowViewTypeLikes) ? LIKES_VIEW_HEIGHT : PHOTOCELL_VIEW_HEIGHT;
  CGFloat avatarHeight   = (_viewType && UserRowViewTypeLikes) ? LIKES_IMAGE_HEIGHT : PHOTOCELL_IMAGE_HEIGHT;
  
  CGRect rect = CGRectMake(HORIZONTAL_BUFFER, (viewHeight - avatarHeight) / 2.0, avatarHeight, avatarHeight);
  _userAvatarImageView.frame = rect;
  
  if (_viewType == UserRowViewTypeLikes) {
    
    rect.size                 = _followingStatusBtn.bounds.size;
    rect.origin.x             = boundsSize.width - HORIZONTAL_BUFFER - rect.size.width;
    rect.origin.y             = (viewHeight - rect.size.height) / 2.0;
    _followingStatusBtn.frame = rect;
    
  } else {
    
    rect.size              = _photoTimeIntervalSincePostLabel.bounds.size;
    rect.origin.x          = boundsSize.width - HORIZONTAL_BUFFER - rect.size.width;
    rect.origin.y          = (viewHeight - rect.size.height) / 2.0;
    _photoTimeIntervalSincePostLabel.frame = rect;
  }
  
  CGFloat availableWidth = CGRectGetMinX(rect) - HORIZONTAL_BUFFER;
  rect.size              = _userNameLabel.bounds.size;
  rect.size.width        = MIN(availableWidth, rect.size.width);
  rect.origin.x          = HORIZONTAL_BUFFER + avatarHeight + HORIZONTAL_BUFFER;
  
  if (_detailLabel.attributedText) {
    CGSize locationSize  = _userNameLabel.bounds.size;
    locationSize.width   = MIN(availableWidth, locationSize.width);
    
    rect.origin.y        = (viewHeight - rect.size.height - locationSize.height) / 2.0;
    _userNameLabel.frame = rect;
    
    // FIXME: Name rects at least for this sub-condition
    rect.origin.y       += rect.size.height;
    rect.size            = locationSize;
    _detailLabel.frame   = rect;
    
  } else {
    rect.origin.y        = (viewHeight - rect.size.height) / 2.0;
    _userNameLabel.frame = rect;
  }
}

- (void)updateWithPhotoModel:(PhotoModel *)photo
{
  [self clearFields];
  
  _photo                        = photo;
  _userNameLabel.attributedText = [photo.ownerUserProfile usernameAttributedStringWithFontSize:FONT_SIZE];
  [_userNameLabel sizeToFit];
  
//  [self downloadAndProcessUserAvatarForPhoto:photo];

  switch (_viewType) {
    case UserRowViewTypeLikes:
      
      _detailLabel.attributedText = [photo.ownerUserProfile fullNameAttributedStringWithFontSize:FONT_SIZE];
      [_detailLabel sizeToFit];
    
      _followingStatusBtn.selected = YES;                    // FIXME:
      _followingStatusBtn.frame = CGRectMake(0, 0, 20, 30);  // FIXME:
      break;
      
    case UserRowViewTypePhotoCell:
      [self reverseGeocodeLocationForPhoto:photo];
      _photoTimeIntervalSincePostLabel.attributedText = [photo uploadDateAttributedStringWithFontSize:FONT_SIZE];
      [_photoTimeIntervalSincePostLabel sizeToFit];
      break;
      
    default:
      break;
  }
  
  [self setNeedsLayout];
}

- (void)updateWithCommentModel:(CommentModel *)comment
{
  [self clearFields];
  
  _comment                      = comment;
  _userNameLabel.attributedText = [[NSAttributedString alloc] initWithString:comment.commenterUsername];  // FIXME:
  [_userNameLabel sizeToFit];

  _detailLabel.attributedText =  [comment commentAttributedString];    //FIXME: add userModel to commentModel? don't include user name!!!
  [_detailLabel sizeToFit];
  
  _photoTimeIntervalSincePostLabel.attributedText = [comment uploadDateAttributedStringWithFontSize:FONT_SIZE];
  [_photoTimeIntervalSincePostLabel sizeToFit];
  
  [self downloadAndProcessUserAvatarForURLString:comment.commenterAvatarURL];
  
  [self setNeedsLayout];
}


#pragma mark - Helper Methods

- (void)downloadAndProcessUserAvatarForURLString:(NSString *)urlString
{
  CGFloat avatarHeight   = (_viewType == UserRowViewTypeLikes) ? LIKES_IMAGE_HEIGHT : PHOTOCELL_IMAGE_HEIGHT;

  [_userAvatarImageView pin_setImageFromURL:[NSURL URLWithString:urlString] processorKey:@"custom" processor:^UIImage * _Nullable(PINRemoteImageManagerResult * _Nonnull result, NSUInteger * _Nonnull cost) {
    CGSize profileImageSize = CGSizeMake(avatarHeight, avatarHeight);
    return [result.image makeCircularImageWithSize:profileImageSize];
  }];
}

- (void)reverseGeocodeLocationForPhoto:(PhotoModel *)photo
{
  [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
    
    // check and make sure this is still relevant for this cell (and not an old cell)
    // make sure to use _photoModel instance variable as photo may change when cell is reused,
    // where as local variable will never change
    if (locationModel == _photo.location) {
      _detailLabel.attributedText = [photo locationAttributedStringWithFontSize:FONT_SIZE];
      [_detailLabel sizeToFit];
      [self setNeedsLayout];
    }
  }];
}

- (void)clearFields
{
  _photo                                          = nil;
  _comment                                        = nil;
  _userAvatarImageView.image                      = nil;
  _userNameLabel.attributedText                   = nil;
  _detailLabel.attributedText                     = nil;
  _photoTimeIntervalSincePostLabel.attributedText = nil;
  _followingStatusBtn.frame                       = CGRectZero;
  _photoTimeIntervalSincePostLabel.frame          = CGRectZero;
}

@end
