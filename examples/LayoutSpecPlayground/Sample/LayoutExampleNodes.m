//
//  LayoutExampleNodes.m
//  Sample
//
//  Created by Hannah Troisi on 9/13/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "LayoutExampleNodes.h"
#import "Utilities.h"
#import "UIImage+ASConvenience.h"

#define USER_IMAGE_HEIGHT       60
#define HORIZONTAL_BUFFER       10
#define VERTICAL_BUFFER         5
#define FONT_SIZE               20

@implementation LayoutExampleNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    self.automaticallyManagesSubnodes = YES;
    self.shouldVisualizeLayoutSpecs = NO;
    self.shouldCacheLayoutSpec = NO;
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
    _usernameNode = [[ASTextNode alloc] init];
    _usernameNode.attributedText = [self usernameAttributedStringWithFontSize:FONT_SIZE];
    
    _postLocationNode = [[ASTextNode alloc] init];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.attributedText = [self locationAttributedStringWithFontSize:FONT_SIZE];
    
    _postTimeNode = [[ASTextNode alloc] init];
    _postTimeNode.attributedText = [self uploadDateAttributedStringWithFontSize:FONT_SIZE];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _usernameNode.style.flexShrink = 1.0;
  _postLocationNode.style.flexShrink = 1.0;

  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackSpec.style.flexShrink = 1.0;
  
  // Example: see ASDKgram for how this technique can be used to animate in the location label
  // once a separate network request provides the data.
  if (_postLocationNode.attributedText) {
    [verticalStackSpec setChildren:@[_usernameNode, _postLocationNode]];
  } else {
    [verticalStackSpec setChildren:@[_usernameNode]];
  }
  
  ASLayoutSpec *spacerSpec = [[ASLayoutSpec alloc] init];
  spacerSpec.style.flexGrow = 1.0;
  spacerSpec.style.flexShrink = 1.0;
  
  // horizontal stack
  ASStackLayoutSpec *horizontalStackSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStackSpec.alignItems = ASStackLayoutAlignItemsCenter; // center items vertically in horiz stack
  horizontalStackSpec.justifyContent = ASStackLayoutJustifyContentStart; // justify content to left
  horizontalStackSpec.style.flexShrink = 1.0;
  horizontalStackSpec.style.flexGrow = 1.0;
  [horizontalStackSpec setChildren:@[verticalStackSpec, spacerSpec, _postTimeNode]];
  
  // inset horizontal stack
  UIEdgeInsets insets = UIEdgeInsetsMake(0, 10, 0, 10);
  ASInsetLayoutSpec *headerInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:horizontalStackSpec];
  headerInsetSpec.style.flexShrink = 1.0;
  headerInsetSpec.style.flexGrow = 1.0;
  
  return headerInsetSpec;
}

@end


@implementation PhotoWithInsetTextOverlay

- (instancetype)init
{
  self = [super init];
  
  if (self) {
    _photoNode = [[ASNetworkImageNode alloc] init];
    _photoNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-inset-text-overlay-photo.png"];
    
    _titleNode = [[ASTextNode alloc] init];
    _titleNode.maximumNumberOfLines = 2;
    _titleNode.truncationAttributedText = [NSAttributedString attributedStringWithString:@"..."
                                                                                  fontSize:16
                                                                            color:[UIColor whiteColor]
                                                                   firstWordColor:nil];
    _titleNode.attributedText = [NSAttributedString attributedStringWithString:@"family fall hikes"
                                                                        fontSize:16
                                                                           color:[UIColor whiteColor]
                                                                  firstWordColor:nil];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _photoNode.style.preferredSize = CGSizeMake(USER_IMAGE_HEIGHT*2, USER_IMAGE_HEIGHT*2);
  
  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  ASInsetLayoutSpec *textInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets
                                                                            child:_titleNode];

  ASOverlayLayoutSpec *textOverlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_photoNode
                                                                                 overlay:textInsetSpec];
  
  return textOverlaySpec;
}

@end


@implementation PhotoWithOutsetIconOverlay

- (instancetype)init
{
  self = [super init];
  
  if (self) {

    _photoNode = [[ASNetworkImageNode alloc] init];
    _photoNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-photo.png"];
    
    _iconNode = [[ASNetworkImageNode alloc] init];
    _iconNode.URL = [NSURL URLWithString:@"http://asyncdisplaykit.org/static/images/layout-examples-photo-with-outset-icon-overlay-icon.png"];
    
    [_iconNode setImageModificationBlock:^UIImage *(UIImage *image) {   // FIXME: in framework autocomplete for setImageModificationBlock line seems broken
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
      return [image makeCircularImageWithSize:profileImageSize withBorderWidth:10];
    }];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _iconNode.style.preferredSize = CGSizeMake(40, 40);
  _photoNode.style.preferredSize = CGSizeMake(150, 150);

  CGFloat x = 150;
  CGFloat y = 0;
  
  _iconNode.style.layoutPosition = CGPointMake(x, y);
  _photoNode.style.layoutPosition = CGPointMake(40 / 2.0, 40 / 2.0);
  
  ASAbsoluteLayoutSpec *absoluteLayoutSpec = [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[_photoNode, _iconNode]];
  
  return absoluteLayoutSpec;
}

@end


@implementation FlexibleSeparatorSurroundingContent

- (instancetype)init
{
  self = [super init];
  
  if (self) {
  
    self.backgroundColor = [UIColor cyanColor];

    _topSeparator = [[ASImageNode alloc] init];
    _topSeparator.image = [UIImage as_resizableRoundedImageWithCornerRadius:1.0
                                                                cornerColor:[UIColor blackColor]
                                                                  fillColor:[UIColor blackColor]];
    
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedText = [NSAttributedString attributedStringWithString:@"this is a long text node"
                                                                       fontSize:16
                                                                          color:[UIColor blackColor]
                                                                 firstWordColor:nil];
    
    _bottomSeparator = [[ASImageNode alloc] init];
    _bottomSeparator.image = [UIImage as_resizableRoundedImageWithCornerRadius:1.0
                                                                   cornerColor:[UIColor blackColor]
                                                                     fillColor:[UIColor blackColor]];
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _topSeparator.style.flexGrow = 1.0;
  _bottomSeparator.style.flexGrow = 1.0;

  UIEdgeInsets contentInsets = UIEdgeInsetsMake(10, 10, 10, 10);
  ASInsetLayoutSpec *insetContentSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:contentInsets
                                                                               child:_textNode];
  // final vertical stack
  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackSpec.direction = ASStackLayoutDirectionVertical;
  verticalStackSpec.justifyContent = ASStackLayoutJustifyContentCenter;
  verticalStackSpec.alignItems = ASStackLayoutAlignItemsStretch;
  verticalStackSpec.children = @[_topSeparator, insetContentSpec, _bottomSeparator];

  return verticalStackSpec;
}

@end

