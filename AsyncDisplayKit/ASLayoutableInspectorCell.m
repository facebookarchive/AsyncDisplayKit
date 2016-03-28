//
//  ASLayoutableInspectorCell.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorCell.h"

typedef NS_ENUM(NSInteger, CellDataType) {
  CellDataTypeBool,
  CellDataTypeFloat,
};

@implementation ASLayoutableInspectorCell
{
  ASLayoutablePropertyType      _propertyType;
  CellDataType                  _dataType;
  id<ASLayoutable>              _layoutableToEdit;
  
  ASButtonNode                  *_buttonNode;
  ASTextNode                    *_textNode;
}

#pragma mark - Lifecycle

- (instancetype)initWithProperty:(ASLayoutablePropertyType)property layoutableToEdit:(id<ASLayoutable>)layoutable
{
  self = [super init];
  if (self) {
    
    _propertyType = property;
    _dataType = [ASLayoutableInspectorCell dataTypeForProperty:property];
    _layoutableToEdit = layoutable;
    
    self.usesImplicitHierarchyManagement = YES;
    
    _buttonNode = [self makeBtnNodeWithTitle:[ASLayoutableInspectorCell propertyStringForPropertyType:property]];
    [_buttonNode addTarget:self action:@selector(buttonTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
//    _buttonNode.selected =   // FIXME:
    
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedString = [ASLayoutableInspectorCell propertyValueAttributedStringForProperty:property withLayoutable:layoutable];
    
  }
  return self;
}

+ (NSAttributedString *)propertyValueAttributedStringForProperty:(ASLayoutablePropertyType)property withLayoutable:(id<ASLayoutable>)layoutable
{
  NSString *valueString;
  
  switch (property) {
    case ASLayoutablePropertyFlexGrow:
      valueString = layoutable.flexGrow ? @"YES" : @"NO";
      break;
    case ASLayoutablePropertyFlexShrink:
      valueString = layoutable.flexShrink ? @"YES" : @"NO";
      break;
    case ASLayoutablePropertyAlignSelf:
      valueString = [ASLayoutableInspectorCell alignSelfValueString:layoutable.alignSelf];
      break;
    case ASLayoutablePropertySpacingBefore:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutable.spacingBefore];
      break;
    case ASLayoutablePropertySpacingAfter:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutable.spacingAfter];
      break;
    case ASLayoutablePropertyAscender:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutable.ascender];
      break;
    case ASLayoutablePropertyDescender:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutable.descender];
      break;
    default:
      valueString = @"?";
      break;
  }
  return [ASLayoutableInspectorCell attributedStringFromString:valueString];
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *horizontalSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalSpec.children           = @[_buttonNode, _textNode];
  horizontalSpec.flexGrow           = YES;
  horizontalSpec.alignItems         = ASStackLayoutAlignItemsCenter;
  horizontalSpec.justifyContent     = ASStackLayoutJustifyContentSpaceBetween;
  
  ASInsetLayoutSpec *insetSpec      = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(2, 4, 2, 4) child:horizontalSpec];
  
  return insetSpec;
}

#pragma mark - gesture handling

- (void)buttonTapped:(ASButtonNode *)sender
{
  NSUInteger currentAlignSelfValue;
  NSUInteger nextAlignSelfValue;
  
  switch (_propertyType) {
      
    case ASLayoutablePropertyFlexGrow:
      if ([self layoutSpec]) {
        [[self layoutSpec] setFlexGrow:!sender.isSelected];
      } else if ([self node]) {
        [[self node] setFlexGrow:!sender.isSelected];
      }
      // update .selected & value
      sender.selected            = !sender.selected;
      _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutablePropertyFlexShrink:
      if ([self layoutSpec]) {
        [[self layoutSpec] setFlexShrink:!sender.isSelected];
      } else if ([self node]) {
        [[self node] setFlexGrow:!sender.isSelected];
      }
      // update .selected & value
      sender.selected            = !sender.selected;
      _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutablePropertyAlignSelf:
      if ([self layoutSpec]) {
        currentAlignSelfValue = [[self layoutSpec] alignSelf];
        nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
        [[self layoutSpec] setAlignSelf:nextAlignSelfValue];
    
      } else if ([self node]) {
        currentAlignSelfValue = [[self node] alignSelf];
        nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
        [[self node] setAlignSelf:nextAlignSelfValue];
      }
      
      break;
      
    default:
      break;
  }
  [self setNeedsLayout];
}

#pragma mark - cast layoutableToEdit

- (ASDisplayNode *)node
{
  if ([_layoutableToEdit isKindOfClass:[ASDisplayNode class]]) {
    return (ASDisplayNode *)_layoutableToEdit;
  }
  return nil;
}

- (ASLayoutSpec *)layoutSpec
{
  if ([_layoutableToEdit isKindOfClass:[ASLayoutSpec class]]) {
    return (ASLayoutSpec *)_layoutableToEdit;
  }
  return nil;
}

#pragma mark - data / property type helper methods

+ (CellDataType)dataTypeForProperty:(ASLayoutablePropertyType)property
{
  switch (property) {
      
    case ASLayoutablePropertyFlexGrow:
    case ASLayoutablePropertyFlexShrink:
      return CellDataTypeBool;
      
    case ASLayoutablePropertySpacingBefore:
    case ASLayoutablePropertySpacingAfter:
    case ASLayoutablePropertyAscender:
    case ASLayoutablePropertyDescender:
      return CellDataTypeFloat;
      
    default:
      break;
  }
  return CellDataTypeBool;
}

+ (NSString *)propertyStringForPropertyType:(ASLayoutablePropertyType)property
{
  NSString *string;
  switch (property) {
    case ASLayoutablePropertyFlexGrow:
      string = @"FlexGrow";
      break;
    case ASLayoutablePropertyFlexShrink:
      string = @"FlexShrink";
      break;
    case ASLayoutablePropertyAlignSelf:
      string = @"AlignSelf";
      break;
    case ASLayoutablePropertySpacingBefore:
      string = @"SpacingBefore";
      break;
    case ASLayoutablePropertySpacingAfter:
      string = @"SpacingAfter";
      break;
    case ASLayoutablePropertyAscender:
      string = @"Ascender";
      break;
    case ASLayoutablePropertyDescender:
      string = @"Descender";
      break;
    default:
      string = @"Unknown";
      break;
  }
  return string;
}

+ (NSDictionary *)alignSelfTypeNames
{
  return @{@(ASStackLayoutAlignSelfAuto) : @"Auto",
           @(ASStackLayoutAlignSelfStart) : @"Start",
           @(ASStackLayoutAlignSelfEnd) : @"End",
           @(ASStackLayoutAlignSelfCenter) : @"Center",
           @(ASStackLayoutAlignSelfStretch) : @"Stretch"};
}

+ (NSString *)alignSelfValueString:(NSUInteger)type
{
  return [[self class] alignSelfTypeNames][@(type)];
}


#pragma mark - formatting helper methods

+ (NSAttributedString *)attributedStringFromString:(NSString *)string
{
  return [ASLayoutableInspectorCell attributedStringFromString:string withTextColor:[UIColor whiteColor]];
}

+ (NSAttributedString *)attributedStringFromString:(NSString *)string withTextColor:(nullable UIColor *)color
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
  [btn setAttributedTitle:[ASLayoutableInspectorCell attributedStringFromString:title] forState:ASControlStateNormal];
  [btn setAttributedTitle:[ASLayoutableInspectorCell attributedStringFromString:title withTextColor:[UIColor lightGrayColor]] forState:ASControlStateDisabled];
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