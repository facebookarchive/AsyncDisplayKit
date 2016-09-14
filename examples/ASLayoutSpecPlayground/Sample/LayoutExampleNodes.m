//
//  LayoutExampleNodes.m
//  Sample
//
//  Created by Hannah Troisi on 9/13/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "LayoutExampleNodes.h"
#import "Utilities.h"

#define USER_IMAGE_HEIGHT       60
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               20

@implementation LayoutExampleNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.usesImplicitHierarchyManagement = YES;
    self.shouldVisualizeLayoutSpecs = YES;
    self.shouldCacheLayoutSpec = YES;
    self.backgroundColor = [UIColor whiteColor];
  }
  return self;
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
  NSString *string               = [NSString stringWithFormat:@"hannahmbanana check out this cool pic from the internet!"];
  NSAttributedString *attrString = [NSAttributedString attributedStringWithString:string
                                                                         fontSize:size
                                                                            color:[UIColor darkGrayColor]
                                                                   firstWordColor:[UIColor darkBlueColor]];
  return attrString;
}

@end

@implementation HorizontalStackWithSpacer

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _usernameTextNode                  = [[ASTextNode alloc] init];
    _usernameTextNode.attributedString = [self usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _postTimeTextNode                  = [[ASTextNode alloc] init];
    _postTimeTextNode.attributedString = [self uploadDateAttributedStringWithFontSize:FONT_SIZE];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _usernameTextNode.flexShrink = YES;
  
  ASLayoutSpec *spacer               = [[ASLayoutSpec alloc] init];
  spacer.flexGrow                    = YES;
  spacer.flexShrink                  = YES;
  
  // horizontal stack
  ASStackLayoutSpec *headerStackSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  headerStackSpec.alignItems             = ASStackLayoutAlignItemsCenter;                     // center items vertically in horizontal stack
  headerStackSpec.justifyContent         = ASStackLayoutJustifyContentStart;                  // justify content to the left side of the header stack
  headerStackSpec.flexShrink             = YES;
  headerStackSpec.flexGrow               = YES;
  [headerStackSpec setChildren:@[_usernameTextNode, spacer, _postTimeTextNode]];
  
  // inset horizontal stack
  UIEdgeInsets insets                = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  ASInsetLayoutSpec *headerInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:headerStackSpec];
  headerInsetSpec.flexShrink         = YES;
  headerInsetSpec.flexGrow           = YES;
  
  return headerInsetSpec;
}

@end


@implementation PhotoWithInsetTextOverlay

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _avatarImageNode     = [[ASNetworkImageNode alloc] init];
    _avatarImageNode.URL = [NSURL URLWithString:@"https://s-media-cache-ak0.pinimg.com/avatars/503h_1458880322_140.jpg"];
    
    _usernameTextNode                      = [[ASTextNode alloc] init];
    _usernameTextNode.maximumNumberOfLines = 2;
    _usernameTextNode.truncationAttributedString = [NSAttributedString attributedStringWithString:@"..."
                                                                         fontSize:12
                                                                            color:[UIColor whiteColor]
                                                                   firstWordColor:nil];
    _usernameTextNode.attributedString = [NSAttributedString attributedStringWithString:@"this is a long text description for an image"
                                                                         fontSize:FONT_SIZE/2.0
                                                                            color:[UIColor whiteColor]
                                                                   firstWordColor:nil];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _avatarImageNode.preferredFrameSize           = CGSizeMake(USER_IMAGE_HEIGHT*2, USER_IMAGE_HEIGHT*2);
  ASStaticLayoutSpec *backgroundImageStaticSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[_avatarImageNode]];

  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  ASInsetLayoutSpec *textInset = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_usernameTextNode];

  ASOverlayLayoutSpec *textOverlay = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:backgroundImageStaticSpec overlay:textInset];
  
  return textOverlay;
}

@end


@implementation PhotoWithOutsetIconOverlay

- (instancetype)init
{
  self = [super init];
  
  if (self) {

    _photoImageNode     = [[ASNetworkImageNode alloc] init];
    _photoImageNode.URL = [NSURL URLWithString:@"http://farm4.static.flickr.com/3691/10155174895_8c815250a0_m.jpg"];
    
    _plusIconImageNode     = [[ASNetworkImageNode alloc] init];
    _plusIconImageNode.URL = [NSURL URLWithString:@"http://www.icon100.com/up/3327/256/32-PLus-button.png"];
    
    [_plusIconImageNode setImageModificationBlock:^UIImage *(UIImage *image) {   // FIXME: in framework autocomplete for setImageModificationBlock line seems broken
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize withBorderWidth:10];
    }];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _plusIconImageNode.preferredFrameSize = CGSizeMake(40, 40);
  _photoImageNode.preferredFrameSize = CGSizeMake(150, 150);

  CGFloat x = _photoImageNode.preferredFrameSize.width;
  CGFloat y = 0;
  
  _plusIconImageNode.layoutPosition = CGPointMake(x, y);
  _photoImageNode.layoutPosition = CGPointMake(_plusIconImageNode.preferredFrameSize.height/2.0, _plusIconImageNode.preferredFrameSize.height/2.0);
  
  ASStaticLayoutSpec *staticLayoutSpec = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[_photoImageNode, _plusIconImageNode]];
  
  return staticLayoutSpec;
}

@end

