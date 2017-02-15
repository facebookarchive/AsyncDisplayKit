//
//  ASTextFieldNode.m
//  AsyncDisplayKit
//
//  Created by Kyle Shank on 2/14/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTextFieldNode.h"

#import <AsyncDisplayKit/ASAbsoluteLayoutSpec.h>

@implementation ASTextFieldNode

@synthesize textFieldNode, textField;

-(id) init {
  if (self = [super init]){
    self.textField = [[ASTextFieldView alloc] init];
    self.textFieldNode = [[ASDisplayNode alloc] initWithViewBlock:^{
      return self.textField;
    }];
    self.automaticallyManagesSubnodes = true;
    ASDimension height;
    height.unit = ASDimensionUnitPoints;
    height.value = 31.0;
    self.style.height = height;
    return self;
  }
  return nil;
}

-(UIEdgeInsets)textContainerInset {
  return self.textField.textContainerInset;
}

- (void)setTextContainerInset:(UIEdgeInsets)textContainerInset
{
  self.textField.textContainerInset = textContainerInset;
  ASDimension height;
  height.unit = ASDimensionUnitPoints;
  height.value = [self lineHeight] + textField.textContainerInset.top + textField.textContainerInset.bottom;
  self.style.height = height;
  [self setNeedsLayout];
}

-(UIFont*)font {
  return textField.font;
}

-(void) setFont:(UIFont *)font{
  textField.font = font;
}

-(UIColor*)textColor {
  return textField.textColor;
}

-(void) setTextColor:(UIColor *)textColor{
  textField.textColor = textColor;
}

-(NSString*)text {
  return self.textField.text;
}

-(void) setText:(NSString *)text{
  self.textField.text = text;
}

-(NSAttributedString*)attributedText {
  return self.textField.attributedText;
}

-(void) setAttributedText:(NSAttributedString *)attributedText{
  self.textField.attributedText = attributedText;
}

-(NSAttributedString*)attributedPlaceholder {
  return self.textField.attributedPlaceholder;
}

-(void) setAttributedPlaceholder:(NSAttributedString *)attributedText{
  self.textField.attributedPlaceholder = attributedText;
}

-(UITextAutocapitalizationType) autocapitalizationType {
  return textField.autocapitalizationType;
}

-(void) setAutocapitalizationType:(UITextAutocapitalizationType)autocapitalizationType{
  textField.autocapitalizationType = autocapitalizationType;
}

-(UITextAutocorrectionType) autocorrectionType{
  return textField.autocorrectionType;
}

-(void)setAutocorrectionType:(UITextAutocorrectionType)autocorrectionType{
  textField.autocorrectionType = autocorrectionType;
}

-(UITextSpellCheckingType)spellCheckingType{
  return textField.spellCheckingType;
}

-(void) setSpellCheckingType:(UITextSpellCheckingType)spellCheckingType{
  textField.spellCheckingType = spellCheckingType;
}

-(UIKeyboardType)keyboardType{
  return textField.keyboardType;
}

-(void)setKeyboardType:(UIKeyboardType)keyboardType{
  textField.keyboardType = keyboardType;
}

-(UIKeyboardAppearance)keyboardAppearance{
  return textField.keyboardAppearance;
}

-(void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance{
  textField.keyboardAppearance = keyboardAppearance;
}

-(UIReturnKeyType)returnKeyType{
  return textField.returnKeyType;
}

-(void)setReturnKeyType:(UIReturnKeyType)returnKeyType{
  textField.returnKeyType = returnKeyType;
}

-(BOOL)enablesReturnKeyAutomatically {
  return textField.enablesReturnKeyAutomatically;
}

-(void) setEnablesReturnKeyAutomatically:(BOOL)enablesReturnKeyAutomatically{
  textField.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically;
}

-(BOOL) secureTextEntry {
  return textField.secureTextEntry;
}

-(BOOL)isSecureTextEntry {
  return [self secureTextEntry];
}

-(void)setSecureTextEntry:(BOOL)secureTextEntry{
  textField.secureTextEntry = secureTextEntry;
}

-(UITextContentType) textContentType{
  return textField.textContentType;
}

-(void) setTextContentType:(UITextContentType)textContentType{
  textField.textContentType = textContentType;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASLayoutSize min;
  ASDimension minWidth;
  minWidth.unit = ASDimensionUnitPoints;
  minWidth.value = constrainedSize.min.width;
  ASDimension minHeight;
  minHeight.unit = ASDimensionUnitPoints;
  minHeight.value = constrainedSize.min.height;
  min.width = minWidth;
  min.height = minHeight;
  
  ASLayoutSize max;
  ASDimension maxWidth;
  maxWidth.unit = ASDimensionUnitPoints;
  maxWidth.value = constrainedSize.max.width;
  ASDimension maxHeight;
  maxHeight.unit = ASDimensionUnitPoints;
  maxHeight.value = constrainedSize.max.height;
  max.width = maxWidth;
  max.height = maxHeight;
  
  ASAbsoluteLayoutSpec* spec = [[ASAbsoluteLayoutSpec alloc] init];
  textFieldNode.style.minLayoutSize = min;
  textFieldNode.style.maxLayoutSize = max;
  textFieldNode.style.preferredLayoutSize = textFieldNode.style.maxLayoutSize;
  spec.children = [NSArray arrayWithObject:textFieldNode];
  return spec;
}

-(CGFloat)lineHeight {
  if ( [self font] != nil ){
    return [self font].lineHeight;
  }
  return [UIFont systemFontOfSize:17.0].lineHeight;
}

@end
