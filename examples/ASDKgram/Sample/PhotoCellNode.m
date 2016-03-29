//
//  PhotoCellNode.m
//  Flickrgram
//
//  Created by Hannah Troisi on 2/17/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PhotoCellNode.h"
#import "Utilities.h"
#import "AsyncDisplayKit.h"
#import "ASDisplayNode+Beta.h"
#import "CommentsNode.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"

#define DEBUG_PHOTOCELL_LAYOUT  0

#define HEADER_HEIGHT           50
#define USER_IMAGE_HEIGHT       50
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               14

@interface PhotoCellNode () <UIActionSheetDelegate>
@end

@implementation PhotoCellNode
{
  PhotoModel          *_photoModel;
  CommentsNode        *_photoCommentsView;
  ASNetworkImageNode  *_userAvatarImageView;
  ASNetworkImageNode  *_photoImageView;
  ASTextNode          *_userNameLabel;
  ASTextNode          *_photoLocationLabel;
  ASTextNode          *_photoTimeIntervalSincePostLabel;
  ASTextNode          *_photoLikesLabel;
  ASTextNode          *_photoDescriptionLabel;
}


#pragma mark - Lifecycle

- (instancetype)initWithPhotoObject:(PhotoModel *)photo;
{
  self = [super init];
  
  if (self) {
    
    _photoModel              = photo;
    
    _userAvatarImageView     = [[ASNetworkImageNode alloc] init];
    _userAvatarImageView.URL = photo.ownerUserProfile.userPicURL;   // FIXME: make round
    
    // FIXME: autocomplete for this line seems broken
    [_userAvatarImageView setImageModificationBlock:^UIImage *(UIImage *image) {
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize];
    }];

    _photoImageView          = [[ASNetworkImageNode alloc] init];
    _photoImageView.URL      = photo.URL;
    _photoImageView.layerBacked = YES;
    
    _userNameLabel                  = [[ASTextNode alloc] init];
    _userNameLabel.attributedString = [photo.ownerUserProfile usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _photoLocationLabel      = [[ASTextNode alloc] init];
    _photoLocationLabel.maximumNumberOfLines = 1;
    [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
      
      // check and make sure this is still relevant for this cell (and not an old cell)
      // make sure to use _photoModel instance variable as photo may change when cell is reused,
      // where as local variable will never change
      if (locationModel == _photoModel.location) {
        _photoLocationLabel.attributedString = [[NSAttributedString alloc] initWithString:@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"];
//        _photoLocationLabel.attributedString = [photo locationAttributedStringWithFontSize:FONT_SIZE];
        [self setNeedsLayout];
      }
    }];
    
    _photoTimeIntervalSincePostLabel                  = [[ASTextNode alloc] init];
    _photoTimeIntervalSincePostLabel.layerBacked      = YES;
    _photoTimeIntervalSincePostLabel.attributedString = [photo uploadDateAttributedStringWithFontSize:FONT_SIZE];
    
    _photoLikesLabel                        = [[ASTextNode alloc] init];
    _photoLikesLabel.layerBacked            = YES;
    _photoLikesLabel.attributedString       = [photo likesAttributedStringWithFontSize:FONT_SIZE];
    
    _photoDescriptionLabel                  = [[ASTextNode alloc] init];
    _photoDescriptionLabel.layerBacked      = YES;
    _photoDescriptionLabel.attributedString = [photo descriptionAttributedStringWithFontSize:FONT_SIZE];
    _photoDescriptionLabel.maximumNumberOfLines = 3;
    
    _photoCommentsView = [[CommentsNode alloc] init];
    _photoCommentsView.shouldRasterizeDescendants = YES;
    
    // instead of adding everything addSubnode:
    self.usesImplicitHierarchyManagement = YES;
    
//    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(cellWasLongPressed:)];
//    [self.view addGestureRecognizer:lpgr];
//    
//    // tap gesture recognizer
//    UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(cellWasTapped:)];
//    [self.view addGestureRecognizer:tgr];
    
    [_userAvatarImageView addTarget:self action:@selector(doNothing) forControlEvents:ASControlNodeEventTouchUpInside];
    [_photoLikesLabel     addTarget:self action:@selector(doNothing) forControlEvents:ASControlNodeEventTouchUpInside];
    [_userNameLabel       addTarget:self action:@selector(doNothing) forControlEvents:ASControlNodeEventTouchUpInside];
    _userAvatarImageView.hitTestSlop = UIEdgeInsetsMake(-10, -10, -10, -20);
    _photoLikesLabel.hitTestSlop     = UIEdgeInsetsMake(5, 5, 5, 5);

    
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
     
- (void)doNothing
{
 
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // username / photo location header vertical stack

  CGFloat cellWidth                      = constrainedSize.max.width;
//  CGFloat locationWidth = HORIZONTAL_BUFFER * 3;
  //cellWidth - HORIZONTAL_BUFFER - USER_IMAGE_HEIGHT - HORIZONTAL_BUFFER - HORIZONTAL_BUFFER - _photoTimeIntervalSincePostLabel.frame.size.width - HORIZONTAL_BUFFER;
//  CGSize maxSize = CGSizeMake(locationWidth, CGFLOAT_MAX);
//  CGSize minSize = CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX);
//  _photoLocationLabel.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(minSize), ASRelativeSizeMakeWithCGSize(maxSize));
  _photoLocationLabel.flexShrink = YES;
  _userNameLabel.flexShrink = YES;
  
  ASStackLayoutSpec *headerSubStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  headerSubStack.flexShrink = YES;
  
  if (_photoLocationLabel.attributedString) {
    [headerSubStack setChildren:@[_userNameLabel, _photoLocationLabel]];
  } else {
    [headerSubStack setChildren:@[_userNameLabel]];
  }
  
  // header stack
  
  _userAvatarImageView.preferredFrameSize        = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);     // constrain avatar image frame size
  _photoTimeIntervalSincePostLabel.spacingBefore = HORIZONTAL_BUFFER;                 // hack to remove double spaces around spacer
  
  ASLayoutSpec *spacer      = [[ASLayoutSpec alloc] init]; // FIXME: long locations overflow post time - set max size?
  spacer.flexGrow           = YES;
  spacer.flexShrink         = YES;

  ASStackLayoutSpec *headerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.alignItems         = ASStackLayoutAlignItemsCenter;                     // center items vertically in horizontal stack
  headerStack.justifyContent     = ASStackLayoutJustifyContentStart;                  // justify content to the left side of the header stack
  
  UIEdgeInsets avatarInsets          = UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *avatarInset     = [ASInsetLayoutSpec insetLayoutSpecWithInsets:avatarInsets child:_userAvatarImageView];
  
  headerStack.flexShrink = YES;

  [headerStack setChildren:@[avatarInset, headerSubStack, spacer, _photoTimeIntervalSincePostLabel]];
  
  // header inset stack
  
  UIEdgeInsets insets                = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:headerStack];
  headerWithInset.flexShrink = YES;

  
  // footer stack
  
  ASStackLayoutSpec *footerStack     = [ASStackLayoutSpec verticalStackLayoutSpec];
  footerStack.spacing                = VERTICAL_BUFFER;
  
  [footerStack setChildren:@[_photoLikesLabel, _photoDescriptionLabel, _photoCommentsView]];
  
  // footer inset stack
  
  UIEdgeInsets footerInsets          = UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *footerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:footerInsets child:footerStack];
  
  // vertical stack
  
  
  _photoImageView.preferredFrameSize = CGSizeMake(cellWidth, cellWidth);              // constrain photo frame size
  
  ASStackLayoutSpec *verticalStack   = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.alignItems           = ASStackLayoutAlignItemsStretch;                // stretch headerStack to fill horizontal space
  [verticalStack setChildren:@[headerWithInset, _photoImageView, footerWithInset]];
  verticalStack.flexShrink = YES;

  return verticalStack;
}

- (void)loadCommentsForPhoto:(PhotoModel *)photo
{
  if (photo.commentFeed.numberOfItemsInFeed > 0) {
    [_photoCommentsView updateWithCommentFeedModel:photo.commentFeed];
    
    [self setNeedsLayout];
  }
}


@end
