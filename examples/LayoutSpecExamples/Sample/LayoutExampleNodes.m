//
//  LayoutExampleNodes.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "LayoutExampleNodes.h"

#import <AsyncDisplayKit/UIImage+ASConvenience.h>

#import "Utilities.h"

@interface HeaderWithRightAndLeftItems ()
@property (nonatomic, strong) ASTextNode *usernameNode;
@property (nonatomic, strong) ASTextNode *postLocationNode;
@property (nonatomic, strong) ASTextNode *postTimeNode;
@end

@interface PhotoWithInsetTextOverlay ()
@property (nonatomic, strong) ASNetworkImageNode *photoNode;
@property (nonatomic, strong) ASTextNode *titleNode;
@end

@interface PhotoWithOutsetIconOverlay ()
@property (nonatomic, strong) ASNetworkImageNode *photoNode;
@property (nonatomic, strong) ASNetworkImageNode *iconNode;
@end

@interface FlexibleSeparatorSurroundingContent ()
@property (nonatomic, strong) ASImageNode *topSeparator;
@property (nonatomic, strong) ASImageNode *bottomSeparator;
@property (nonatomic, strong) ASTextNode *textNode;
@end

@implementation HeaderWithRightAndLeftItems

+ (NSString *)title
{
  return @"Header with left and right justified text";
}

+ (NSString *)descriptionTitle
{
  return @"try rotating me!";
}

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _usernameNode = [[ASTextNode alloc] init];
    _usernameNode.attributedText = [NSAttributedString attributedStringWithString:@"hannahmbanana"
                                                                         fontSize:20
                                                                            color:[UIColor darkBlueColor]];
    _usernameNode.maximumNumberOfLines = 1;
    _usernameNode.truncationMode = NSLineBreakByTruncatingTail;
    
    _postLocationNode = [[ASTextNode alloc] init];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.attributedText = [NSAttributedString attributedStringWithString:@"Sunset Beach, San Fransisco, CA"
                                                                             fontSize:20
                                                                                color:[UIColor lightBlueColor]];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.truncationMode = NSLineBreakByTruncatingTail;
    
    _postTimeNode = [[ASTextNode alloc] init];
    _postTimeNode.attributedText = [NSAttributedString attributedStringWithString:@"30m"
                                                                         fontSize:20
                                                                            color:[UIColor lightGrayColor]];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.truncationMode = NSLineBreakByTruncatingTail;
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{

  ASStackLayoutSpec *nameLocationStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  nameLocationStack.style.flexShrink = 1.0;
  nameLocationStack.style.flexGrow = 1.0;
  
  if (_postLocationNode.attributedText) {
    nameLocationStack.children = @[_usernameNode, _postLocationNode];
  } else {
    nameLocationStack.children = @[_usernameNode];
  }
  
  ASStackLayoutSpec *headerStackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                               spacing:40
                                                                        justifyContent:ASStackLayoutJustifyContentStart
                                                                            alignItems:ASStackLayoutAlignItemsCenter
                                                                              children:@[nameLocationStack, _postTimeNode]];
  
  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(0, 10, 0, 10) child:headerStackSpec];
}

@end


@implementation PhotoWithInsetTextOverlay

+ (NSString *)title
{
  return @"Photo with inset text overlay";
}

+ (NSString *)descriptionTitle
{
  return @"try rotating me!";
}

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    
    _photoNode = [[ASNetworkImageNode alloc] init];
    _photoNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png"];
    _photoNode.willDisplayNodeContentWithRenderingContext = ^(CGContextRef context) {
      CGRect bounds = CGContextGetClipBoundingBox(context);
      [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:10] addClip];
    };
    
    _titleNode = [[ASTextNode alloc] init];
    _titleNode.maximumNumberOfLines = 2;
    _titleNode.truncationMode = NSLineBreakByTruncatingTail;
    _titleNode.truncationAttributedText = [NSAttributedString attributedStringWithString:@"..." fontSize:16 color:[UIColor whiteColor]];
    _titleNode.attributedText = [NSAttributedString attributedStringWithString:@"family fall hikes" fontSize:16 color:[UIColor whiteColor]];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGFloat photoDimension = constrainedSize.max.width / 4.0;
  _photoNode.style.preferredSize = CGSizeMake(photoDimension, photoDimension);

  // INFINITY is used to make the inset unbounded
  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  ASInsetLayoutSpec *textInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_titleNode];
  
  return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_photoNode overlay:textInsetSpec];;
}

@end


@implementation PhotoWithOutsetIconOverlay

+ (NSString *)title
{
  return @"Photo with outset icon overlay";
}

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _photoNode = [[ASNetworkImageNode alloc] init];
    _photoNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-photo.png"];
    
    _iconNode = [[ASNetworkImageNode alloc] init];
    _iconNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-icon.png"];
    
    [_iconNode setImageModificationBlock:^UIImage *(UIImage *image) {   // FIXME: in framework autocomplete for setImageModificationBlock line seems broken
      CGSize profileImageSize = CGSizeMake(60, 60);
      return [image makeCircularImageWithSize:profileImageSize withBorderWidth:10];
    }];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _iconNode.style.preferredSize = CGSizeMake(40, 40);
  _iconNode.style.layoutPosition = CGPointMake(150, 0);
  
  _photoNode.style.preferredSize = CGSizeMake(150, 150);
  _photoNode.style.layoutPosition = CGPointMake(40 / 2.0, 40 / 2.0);
  
  ASAbsoluteLayoutSpec *absoluteSpec = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[_photoNode, _iconNode]];
  
  // ASAbsoluteLayoutSpec's .sizing property recreates the behavior of ASDK Layout API 1.0's "ASStaticLayoutSpec"
  absoluteSpec.sizing = ASAbsoluteLayoutSpecSizingSizeToFit;
  
  return absoluteSpec;
}



@end


@implementation FlexibleSeparatorSurroundingContent

+ (NSString *)title
{
  return @"Top and bottom cell separator lines";
}

+ (NSString *)descriptionTitle
{
  return @"try rotating me!";
}

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    self.backgroundColor = [UIColor whiteColor];

    _topSeparator = [[ASImageNode alloc] init];
    _topSeparator.image = [UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor blackColor] fillColor:[UIColor blackColor]];
    
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedText = [NSAttributedString attributedStringWithString:@"this is a long text node"
                                                                     fontSize:16
                                                                        color:[UIColor blackColor]];
    
    _bottomSeparator = [[ASImageNode alloc] init];
    _bottomSeparator.image = [UIImage as_resizableRoundedImageWithCornerRadius:1.0 cornerColor:[UIColor blackColor] fillColor:[UIColor blackColor]];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _topSeparator.style.flexGrow = 1.0;
  _bottomSeparator.style.flexGrow = 1.0;
  _textNode.style.alignSelf = ASStackLayoutAlignSelfCenter;
  
  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackSpec.spacing = 20;
  verticalStackSpec.justifyContent = ASStackLayoutJustifyContentCenter;
  verticalStackSpec.children = @[_topSeparator, _textNode, _bottomSeparator];

  return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(60, 0, 60, 0) child:verticalStackSpec];
}

@end

@implementation LayoutExampleNode

+ (NSString *)title
{
  NSAssert(NO, @"All layout example nodes must provide a title!");
  return nil;
}

+ (NSString *)descriptionTitle
{
  return nil;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.automaticallyManagesSubnodes = YES;
    self.backgroundColor = [UIColor whiteColor];
  }
  return self;
}

@end

