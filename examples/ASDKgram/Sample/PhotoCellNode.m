//
//  PhotoCellNode.m
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

#import "PhotoCellNode.h"
#import "Utilities.h"
#import "AsyncDisplayKit.h"
#import "ASDisplayNode+Beta.h"
#import "CommentsNode.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"

// Use this to change the formatting of code you want in layoutSpecs.
#define FLAT_LAYOUT 0

#define DEBUG_PHOTOCELL_LAYOUT  0

#define HEADER_HEIGHT           50
#define USER_IMAGE_HEIGHT       30
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               14

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
    _userNameLabel.attributedText = [photo.ownerUserProfile usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _photoLocationLabel      = [[ASTextNode alloc] init];
    _photoLocationLabel.maximumNumberOfLines = 1;
    [photo.location reverseGeocodedLocationWithCompletionBlock:^(LocationModel *locationModel) {
      
      // check and make sure this is still relevant for this cell (and not an old cell)
      // make sure to use _photoModel instance variable as photo may change when cell is reused,
      // where as local variable will never change
      if (locationModel == _photoModel.location) {
        _photoLocationLabel.attributedText = [photo locationAttributedStringWithFontSize:FONT_SIZE];
        [self setNeedsLayout];
      }
    }];
    
    _photoTimeIntervalSincePostLabel = [self createLayerBackedTextNodeWithString:[photo uploadDateAttributedStringWithFontSize:FONT_SIZE]];
    _photoLikesLabel                 = [self createLayerBackedTextNodeWithString:[photo likesAttributedStringWithFontSize:FONT_SIZE]];
    _photoDescriptionLabel           = [self createLayerBackedTextNodeWithString:[photo descriptionAttributedStringWithFontSize:FONT_SIZE]];
    _photoDescriptionLabel.maximumNumberOfLines = 3;
    
    _photoCommentsView = [[CommentsNode alloc] init];
    
    _photoCommentsView.shouldRasterizeDescendants = YES;
    
    // instead of adding everything addSubnode:
    self.automaticallyManagesSubnodes = YES;
    
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

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
#if FLAT_LAYOUT   // This returns the layout specs in a flat structure.
  // Avatar image with inset
  _userAvatarImageView.style.preferredSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
  ASInsetLayoutSpec *avatarInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER)
                                                                          child:_userAvatarImageView];
  
  // User and photo location stack
  ASStackLayoutSpec *userPhotoLocationStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  userPhotoLocationStack.style.flexShrink = 1.0;
  _userNameLabel.style.flexShrink = 1.0;
  if (_photoLocationLabel.attributedText) {
    _photoLocationLabel.style.flexShrink = 1.0;
    [userPhotoLocationStack setChildren:@[_userNameLabel, _photoLocationLabel]];
  } else {
    [userPhotoLocationStack setChild:_userNameLabel];
  }
  
  // Spacer between user / photo location and photo time inverval
  ASLayoutSpec *spacer = [ASLayoutSpec new];
  spacer.style.flexGrow = 1.0;
  
  // Photo and time interval node
  _photoTimeIntervalSincePostLabel.style.spacingBefore = HORIZONTAL_BUFFER;
  
  // Header stack
  ASStackLayoutSpec *headerStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStack.alignItems = ASStackLayoutAlignItemsCenter;
  headerStack.children = @[avatarInset, userPhotoLocationStack, spacer, _photoTimeIntervalSincePostLabel];
  
  ASInsetLayoutSpec *headerStackInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER)
                                                                               child:headerStack];
  
  // Center photo with ratio
  ASRatioLayoutSpec *centerPhoto = [ASRatioLayoutSpec ratioLayoutSpecWithRatio:1.0 child:_photoImageView];
  
  // Footer stack
  ASStackLayoutSpec *footerStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  footerStack.spacing = VERTICAL_BUFFER;
  footerStack.children = @[_photoLikesLabel, _photoDescriptionLabel, _photoCommentsView];
  
  ASInsetLayoutSpec *footerInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER)
                                                                          child:footerStack];
  
  // Main stack
  ASStackLayoutSpec *mainStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  mainStack.children = @[headerStackInset, centerPhoto, footerInset];
  return mainStack;
  
#else   // This demonstrates how the final layout tree would look like.
  return
  // Main stack
  [ASStackLayoutSpec
   stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
   spacing:0
   justifyContent:ASStackLayoutJustifyContentStart
   alignItems:ASStackLayoutAlignItemsStretch
   children:@[
              
              // Header stack with inset
              [ASInsetLayoutSpec
               insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER)
               child:
               // Header stack
               [ASStackLayoutSpec
                stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                spacing:0.0
                justifyContent:ASStackLayoutJustifyContentStart
                alignItems:ASStackLayoutAlignItemsCenter
                children:@[
                           // Avatar image with inset
                           [ASInsetLayoutSpec
                            insetLayoutSpecWithInsets:UIEdgeInsetsMake(HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER, HORIZONTAL_BUFFER)
                            child:
                            [_userAvatarImageView styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.preferredSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
               }]
                            ],
                           // User and photo location stack
                           [[ASStackLayoutSpec
                             stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                             spacing:0.0
                             justifyContent:ASStackLayoutJustifyContentStart
                             alignItems:ASStackLayoutAlignItemsStretch
                             children:_photoLocationLabel.attributedText ? @[
                                                                             [_userNameLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }],
                                                                             [_photoLocationLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }]
                                                                             ] :
                             @[
                               [_userNameLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexShrink = 1.0;
               }]
                               ]]
                            styledWithBlock:^(ASLayoutElementStyle *style) {
                              style.flexShrink = 1.0;
                            }],
                           // Spacer between user / photo location and photo time inverval
                           [[ASLayoutSpec new] styledWithBlock:^(ASLayoutElementStyle *style) {
                 style.flexGrow = 1.0;
               }],
                           // Photo and time interval node
                           [_photoTimeIntervalSincePostLabel styledWithBlock:^(ASLayoutElementStyle *style) {
                 // to remove double spaces around spacer
                 style.spacingBefore = HORIZONTAL_BUFFER;
               }]
                           ]]
               ],
              
              // Center photo with ratio
              [ASRatioLayoutSpec
               ratioLayoutSpecWithRatio:1.0
               child:_photoImageView],
              
              // Footer stack with inset
              [ASInsetLayoutSpec
               insetLayoutSpecWithInsets:UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER)
               child:
               [ASStackLayoutSpec
                stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                spacing:VERTICAL_BUFFER
                justifyContent:ASStackLayoutJustifyContentStart
                alignItems:ASStackLayoutAlignItemsStretch
                children:@[
                           _photoLikesLabel,
                           _photoDescriptionLabel,
                           _photoCommentsView
                           ]]
               ]
          ]];
#endif
}

#pragma mark - Instance Methods

- (void)didEnterPreloadState
{
  [super didEnterPreloadState];
  
  [_photoModel.commentFeed refreshFeedWithCompletionBlock:^(NSArray *newComments) {
    [self loadCommentsForPhoto:_photoModel];
  }];
}

#pragma mark - Helper Methods

- (ASTextNode *)createLayerBackedTextNodeWithString:(NSAttributedString *)attributedString
{
  ASTextNode *textNode      = [[ASTextNode alloc] init];
  textNode.layerBacked      = YES;
  textNode.attributedText = attributedString;
  return textNode;
}

- (void)loadCommentsForPhoto:(PhotoModel *)photo
{
  if (photo.commentFeed.numberOfItemsInFeed > 0) {
    [_photoCommentsView updateWithCommentFeedModel:photo.commentFeed];
    
    [self setNeedsLayout];
  }
}

@end
