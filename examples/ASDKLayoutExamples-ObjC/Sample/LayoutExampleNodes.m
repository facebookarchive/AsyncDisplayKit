//
//  LayoutExampleNodes.m
//  Sample
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

#import "LayoutExampleNodes.h"
#import "Utilities.h"
#import "UIImage+ASConvenience.h"

#define USER_IMAGE_HEIGHT       60
#define FONT_SIZE               20


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
    _usernameNode.attributedText = [self usernameAttributedStringWithFontSize:FONT_SIZE];
    _usernameNode.maximumNumberOfLines = 1;
    _usernameNode.truncationMode = NSLineBreakByTruncatingTail;
    
    _postLocationNode = [[ASTextNode alloc] init];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.attributedText = [self locationAttributedStringWithFontSize:FONT_SIZE];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.truncationMode = NSLineBreakByTruncatingTail;
    
    _postTimeNode = [[ASTextNode alloc] init];
    _postTimeNode.attributedText = [self uploadDateAttributedStringWithFontSize:FONT_SIZE];
    _postLocationNode.maximumNumberOfLines = 1;
    _postLocationNode.truncationMode = NSLineBreakByTruncatingTail;
  }
  
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // when the username / location text is too long, shrink the stack to fit onscreen rather than push content to the right, offscreen
  ASStackLayoutSpec *nameLocationStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  nameLocationStack.style.flexShrink = YES;
  nameLocationStack.style.flexGrow = YES;
  
  // if fetching post location data from server, check if it is available yet and include it if so
  if (_postLocationNode.attributedText) {
    nameLocationStack.children = @[_usernameNode, _postLocationNode];
  } else {
    nameLocationStack.children = @[_usernameNode];
  }
  
  // horizontal stack
  ASStackLayoutSpec *headerStackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                               spacing:40
                                                                        justifyContent:ASStackLayoutJustifyContentStart
                                                                            alignItems:ASStackLayoutAlignItemsCenter
                                                                              children:@[nameLocationStack, _postTimeNode]];
  
  // inset the horizontal stack
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
  _photoNode.style.preferredSize = CGSizeMake(constrainedSize.max.width / 4.0, constrainedSize.max.width / 4.0);

  // INIFINITY is used to make the inset unbounded
  UIEdgeInsets insets = UIEdgeInsetsMake(INFINITY, 12, 12, 12);
  ASInsetLayoutSpec *textInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_titleNode];

  ASOverlayLayoutSpec *textOverlaySpec = [ASOverlayLayoutSpec overlayLayoutSpecWithChild:_photoNode
                                                                                 overlay:textInsetSpec];
  
  return textOverlaySpec;
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
      CGSize profileImageSize = CGSizeMake(USER_IMAGE_HEIGHT, USER_IMAGE_HEIGHT);
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
  
  return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithSizing:ASAbsoluteLayoutSpecSizingSizeToFit
                                                   children:@[_photoNode, _iconNode]];
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
  _topSeparator.style.flexGrow = YES;
  _bottomSeparator.style.flexGrow = YES;
  _textNode.style.alignSelf = ASStackLayoutAlignSelfCenter;
  
  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:20
                                                                          justifyContent:ASStackLayoutJustifyContentCenter
                                                                              alignItems:ASStackLayoutAlignItemsStretch
                                                                                children:@[_topSeparator, _textNode, _bottomSeparator]];

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


- (NSAttributedString *)usernameAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"hannahmbanana"
                                               fontSize:size
                                                  color:[UIColor darkBlueColor]
                                         firstWordColor:nil];
}

- (NSAttributedString *)locationAttributedStringWithFontSize:(CGFloat)size
{
  return [NSAttributedString attributedStringWithString:@"Sunset Beach, San Fransisco, CA"
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

