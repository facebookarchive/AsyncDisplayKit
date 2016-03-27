//
//  ASLayoutableInspectorCell.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorCell.h"

@implementation ASLayoutableInspectorCell
{
  ASButtonNode *_buttonNode;
  ASTextNode   *_textNode;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    self.usesImplicitHierarchyManagement = YES;
    
    _buttonNode = [self makeBtnNodeWithTitle:@"flexGrow"];
    [_buttonNode addTarget:self action:@selector(buttonTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _textNode   = [[ASTextNode alloc] init];
    _textNode.attributedString = [self attributedStringFromString:@"YES"];
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASLayoutSpec *spacer              = [[ASLayoutSpec alloc] init];
  spacer.flexGrow                   = YES;
  spacer.flexShrink                 = YES;
  
  ASStackLayoutSpec *horizontalSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalSpec.children           = @[_buttonNode, spacer, _textNode];
  horizontalSpec.flexGrow           = YES;
  
  return horizontalSpec;
}

#pragma mark - gesture handling

- (void)buttonTapped:(ASButtonNode *)sender
{
  
}

#pragma mark - helper methods

- (NSAttributedString *)attributedStringFromString:(NSString *)string
{
  return [self attributedStringFromString:string withTextColor:[UIColor whiteColor]];
}

- (NSAttributedString *)attributedStringFromString:(NSString *)string withTextColor:(nullable UIColor *)color
{
  NSDictionary *attributes = @{NSForegroundColorAttributeName : color,
                               NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular" size:12]};
  
  return [[NSAttributedString alloc] initWithString:string attributes:attributes];
}

- (ASButtonNode *)makeBtnNodeWithTitle:(NSString *)title
{
  UIColor *orangeColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
  UIImage *orangeStretchBtnImg = [ASLayoutableInspectorCell imageForButtonWithBackgroundColor:orangeColor
                                                                                  borderColor:[UIColor whiteColor]
                                                                                  borderWidth:3];
  UIImage *greyStretchBtnImg = [ASLayoutableInspectorCell imageForButtonWithBackgroundColor:[UIColor darkGrayColor]
                                                                                borderColor:[UIColor lightGrayColor]
                                                                                borderWidth:3];
  UIImage *clearStretchBtnImg = [ASLayoutableInspectorCell imageForButtonWithBackgroundColor:[UIColor clearColor]
                                                                                 borderColor:[UIColor whiteColor]
                                                                                 borderWidth:3];
  ASButtonNode *btn = [[ASButtonNode alloc] init];
  btn.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
  [btn setAttributedTitle:[self attributedStringFromString:title] forState:ASControlStateNormal];
  [btn setAttributedTitle:[self attributedStringFromString:title withTextColor:[UIColor lightGrayColor]] forState:ASControlStateDisabled];
  [btn setBackgroundImage:clearStretchBtnImg forState:ASControlStateNormal];
  [btn setBackgroundImage:orangeStretchBtnImg forState:ASControlStateSelected];
  [btn setBackgroundImage:greyStretchBtnImg forState:ASControlStateDisabled];
  
  return btn;
}

#define CORNER_RADIUS 3
+ (UIImage *)imageForButtonWithBackgroundColor:(UIColor *)backgroundColor borderColor:(UIColor *)borderColor borderWidth:(CGFloat)width
{
  CGSize unstretchedSize  = CGSizeMake(2 * CORNER_RADIUS + 1, 2 * CORNER_RADIUS + 1);
  CGRect rect             = (CGRect) {CGPointZero, unstretchedSize};
  UIBezierPath *path      = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:CORNER_RADIUS];
  
  // create a graphics context for the following status button
  UIGraphicsBeginImageContextWithOptions(unstretchedSize, NO, 0);
  
  [path addClip];
  [backgroundColor setFill];
  [path fill];
  
  path.lineWidth = width;
  [borderColor setStroke];
  [path stroke];
  
  UIImage *btnImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return [btnImage stretchableImageWithLeftCapWidth:CORNER_RADIUS topCapHeight:CORNER_RADIUS];
}

@end