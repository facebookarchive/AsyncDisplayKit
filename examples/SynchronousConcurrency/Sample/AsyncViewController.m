//
//  AsyncViewController.m
//  Sample
//
//  Created by Scott Goodson on 9/26/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import "AsyncViewController.h"
#import "RandomCoreGraphicsNode.h"

@implementation AsyncViewController {
  ASTextNode *_textNode;
}

- (instancetype)init
{
  if (!(self = [super initWithNode:[[RandomCoreGraphicsNode alloc] init]])) {
    return nil;
  }
  
  _textNode = [[ASTextNode alloc] init];
  _textNode.placeholderEnabled = NO;
  _textNode.attributedString = [[NSAttributedString alloc] initWithString:@"Hello, ASDK!"
                                                               attributes:[self _textStyle]];
  [self.node addSubnode:_textNode];

  self.neverShowPlaceholders = YES;
  self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFavorites tag:0];
  return self;
}

- (void)viewWillAppear:(BOOL)animated
{
  // FIXME: This is only being called on the first time the UITabBarController shows us.
  [super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [self.node recursivelyClearContents];
  [super viewDidDisappear:animated];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:_textNode];
}

- (NSDictionary *)_textStyle
{
  UIFont *font = [UIFont fontWithName:@"HelveticaNeue" size:36.0f];
  
  NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
  style.paragraphSpacing = 0.5 * font.lineHeight;
  style.hyphenationFactor = 1.0;
  
  return @{ NSFontAttributeName: font,
            NSParagraphStyleAttributeName: style };
}

@end
