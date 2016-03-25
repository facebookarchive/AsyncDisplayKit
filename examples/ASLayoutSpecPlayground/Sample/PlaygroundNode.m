//
//  PlaygroundNode.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "PlaygroundNode.h"
#import "ColorNode.h"
#import "AsyncDisplayKit+Debug.h"
#import "ASLayoutableInspectorNode.h"
#import "Utilities.h"

#define USER_IMAGE_HEIGHT       60
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               20

@implementation PlaygroundNode
{
  ASNetworkImageNode  *_userAvatarImageView;
  ASNetworkImageNode  *_photoImageView;
  ASTextNode          *_userNameLabel;
  ASTextNode          *_photoLocationLabel;
  ASTextNode          *_photoTimeIntervalSincePostLabel;
  ASTextNode          *_photoLikesLabel;
  ASTextNode          *_photoDescriptionLabel;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    
    self.backgroundColor                 = [UIColor whiteColor];
    self.usesImplicitHierarchyManagement = YES;
    
    _userAvatarImageView     = [[ASNetworkImageNode alloc] init];
    _userAvatarImageView.URL = [NSURL URLWithString:@"https://s-media-cache-ak0.pinimg.com/avatars/503h_1458880322_140.jpg"];
    
    // FIXME: autocomplete for this line seems broken
    [_userAvatarImageView setImageModificationBlock:^UIImage *(UIImage *image) {
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize];
    }];
    
    _userNameLabel                  = [[ASTextNode alloc] init];
    _userNameLabel.attributedString = [self usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _photoLocationLabel                      = [[ASTextNode alloc] init];
    _photoLocationLabel.maximumNumberOfLines = 1;
    _photoLocationLabel.attributedString     = [self locationAttributedStringWithFontSize:FONT_SIZE];
    
    _photoTimeIntervalSincePostLabel                  = [[ASTextNode alloc] init];
    _photoTimeIntervalSincePostLabel.attributedString = [self uploadDateAttributedStringWithFontSize:FONT_SIZE];
    
    _photoImageView     = [[ASNetworkImageNode alloc] init];
    _photoImageView.URL = [NSURL URLWithString:@"https://s-media-cache-ak0.pinimg.com/564x/9f/5b/3a/9f5b3a35640bc7a5d484b66124c48c46.jpg"];
    
    _photoLikesLabel                  = [[ASTextNode alloc] init];
    _photoLikesLabel.attributedString = [self likesAttributedStringWithFontSize:FONT_SIZE];
    
    _photoDescriptionLabel                      = [[ASTextNode alloc] init];
    _photoDescriptionLabel.attributedString     = [self descriptionAttributedStringWithFontSize:FONT_SIZE];
    _photoDescriptionLabel.maximumNumberOfLines = 3;
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // username / photo location header vertical stack
  
  _userNameLabel.flexShrink         = YES;
  _photoLocationLabel.flexShrink    = YES;

  ASStackLayoutSpec *headerSubStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  headerSubStack.flexShrink         = YES;
  
  if (_photoLocationLabel.attributedString) {
    [headerSubStack setChildren:@[_userNameLabel, _photoLocationLabel]];
  } else {
    [headerSubStack setChildren:@[_userNameLabel]];
  }
  
  // header stack
  
  _userAvatarImageView.preferredFrameSize        = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
  _photoTimeIntervalSincePostLabel.spacingBefore = HORIZONTAL_BUFFER; // hack to remove double spaces around spacer
  
  UIEdgeInsets avatarInsets          = UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *avatarInset     = [ASInsetLayoutSpec insetLayoutSpecWithInsets:avatarInsets child:_userAvatarImageView];
  
  ASLayoutSpec *spacer               = [[ASLayoutSpec alloc] init];
  spacer.flexGrow                    = YES;
  spacer.flexShrink                  = YES;
  
  ASStackLayoutSpec *headerStack     = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.alignItems             = ASStackLayoutAlignItemsCenter;                     // center items vertically in horizontal stack
  headerStack.justifyContent         = ASStackLayoutJustifyContentStart;                  // justify content to the left side of the header stack
  headerStack.flexShrink             = YES;
  headerStack.flexGrow               = YES;
  
  [headerStack setChildren:@[avatarInset, headerSubStack, spacer, _photoTimeIntervalSincePostLabel]];
  
  // header inset stack
  
  UIEdgeInsets insets                = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:headerStack];
  headerWithInset.flexShrink         = YES;
  headerWithInset.flexGrow           = YES;
  
  // footer stack
  
  ASStackLayoutSpec *footerStack     = [ASStackLayoutSpec verticalStackLayoutSpec];
  footerStack.spacing                = VERTICAL_BUFFER;
  
  [footerStack setChildren:@[_photoLikesLabel, _photoDescriptionLabel]];
  
  // footer inset stack
  
  UIEdgeInsets footerInsets          = UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *footerWithInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:footerInsets child:footerStack];
  
  // vertical stack
  
  CGFloat cellWidth                  = constrainedSize.max.width;
  _photoImageView.preferredFrameSize = CGSizeMake(cellWidth, cellWidth);              // constrain photo frame size
  
  ASStackLayoutSpec *verticalStack   = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.alignItems           = ASStackLayoutAlignItemsStretch;                // sretch headerStack to fill horizontal space
  [verticalStack setChildren:@[headerWithInset, _photoImageView, footerWithInset]];
  verticalStack.flexShrink           = YES;
  
  return verticalStack;
}

#pragma mark - helper methods

- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"hannahmbanana"
                                               fontSize:size
                                                  color:[UIColor darkBlueColor]
                                         firstWordColor:nil];
}

- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"San Fransisco, CA"
                                               fontSize:size
                                                  color:[UIColor lightBlueColor]
                                         firstWordColor:nil];
}

- (NSAttributedString *)uploadDateAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"30m"
                                               fontSize:size
                                                  color:[UIColor lightGrayColor]
                                         firstWordColor:nil];
}

- (NSAttributedString *)likesAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"♥︎ 17 likes"
                                               fontSize:size
                                                  color:[UIColor darkBlueColor]
                                         firstWordColor:nil];
}

- (NSAttributedString *)descriptionAttributedStringWithFontSize:(CGFloat)size
{
  NSString *string               = [NSString stringWithFormat:@"hannahtroisi check out this cool pic from the internet!"];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string
                                                                         fontSize:size
                                                                            color:[UIColor darkGrayColor]
                                                                   firstWordColor:[UIColor darkBlueColor]];
  return attrString;
}

@end
