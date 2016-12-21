//
//  ASLayoutElementInspectorCell.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutElementInspectorCell.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSInteger, CellDataType) {
  CellDataTypeBool,
  CellDataTypeFloat,
};

__weak static ASLayoutElementInspectorCell *__currentlyOpenedCell = nil;

@protocol InspectorCellEditingBubbleProtocol <NSObject>
- (void)valueChangedToIndex:(NSUInteger)index;
@end

@interface ASLayoutElementInspectorCellEditingBubble : ASDisplayNode
@property (nonatomic, strong, readwrite) id<InspectorCellEditingBubbleProtocol> delegate;
- (instancetype)initWithEnumOptions:(BOOL)yes enumStrings:(NSArray<NSString *> *)options currentOptionIndex:(NSUInteger)currentOption;
- (instancetype)initWithSliderMinValue:(CGFloat)min maxValue:(CGFloat)max currentValue:(CGFloat)current
;@end

@interface ASLayoutElementInspectorCell () <InspectorCellEditingBubbleProtocol>
@end

@implementation ASLayoutElementInspectorCell
{
  ASLayoutElementPropertyType   _propertyType;
  CellDataType                  _dataType;
  id<ASLayoutElement>           _layoutElementToEdit;
  
  ASButtonNode                  *_buttonNode;
  ASTextNode                    *_textNode;
  ASTextNode                    *_textNode2;
  
  ASLayoutElementInspectorCellEditingBubble *_textBubble;
}

#pragma mark - Lifecycle

- (instancetype)initWithProperty:(ASLayoutElementPropertyType)property layoutElementToEdit:(id<ASLayoutElement>)layoutElement
{
  self = [super init];
  if (self) {
    
    _propertyType = property;
    _dataType = [ASLayoutElementInspectorCell dataTypeForProperty:property];
    _layoutElementToEdit = layoutElement;
    
    self.automaticallyManagesSubnodes = YES;
    
    _buttonNode = [self makeBtnNodeWithTitle:[ASLayoutElementInspectorCell propertyStringForPropertyType:property]];
    [_buttonNode addTarget:self action:@selector(buttonTapped:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _textNode = [[ASTextNode alloc] init];
    _textNode.attributedText = [ASLayoutElementInspectorCell propertyValueAttributedStringForProperty:property withLayoutElement:layoutElement];
    
    [self updateButtonStateForProperty:property withLayoutElement:layoutElement];

    _textNode2 = [[ASTextNode alloc] init];
    _textNode2.attributedText = [ASLayoutElementInspectorCell propertyValueDetailAttributedStringForProperty:property withLayoutElement:layoutElement];
    
  }
  return self;
}

- (void)updateButtonStateForProperty:(ASLayoutElementPropertyType)property withLayoutElement:(id<ASLayoutElement>)layoutElement
{
  if (property == ASLayoutElementPropertyFlexGrow) {
    _buttonNode.selected = layoutElement.style.flexGrow;
  }
  else if (property == ASLayoutElementPropertyFlexShrink) {
    _buttonNode.selected = layoutElement.style.flexShrink;
  }
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *horizontalSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalSpec.children           = @[_buttonNode, _textNode];
  horizontalSpec.style.flexGrow     = 1.0;
  horizontalSpec.alignItems         = ASStackLayoutAlignItemsCenter;
  horizontalSpec.justifyContent     = ASStackLayoutJustifyContentSpaceBetween;
  
  ASLayoutSpec *childSpec;
  if (_textBubble) {
    ASStackLayoutSpec *verticalSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
    verticalSpec.children           = @[horizontalSpec, _textBubble];
    verticalSpec.spacing            = 8;
    verticalSpec.style.flexGrow     = 1.0;
    _textBubble.style.flexGrow      = 1.0;
    childSpec = verticalSpec;
  } else {
    childSpec = horizontalSpec;
  }
  ASInsetLayoutSpec *insetSpec     = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(2, 4, 2, 4) child:childSpec];
  insetSpec.style.flexGrow         =1.0;
  
  return insetSpec;
}

+ (NSAttributedString *)propertyValueAttributedStringForProperty:(ASLayoutElementPropertyType)property withLayoutElement:(id<ASLayoutElement>)layoutElement
{
  NSString *valueString;
  
  switch (property) {
    case ASLayoutElementPropertyFlexGrow:
      valueString = layoutElement.style.flexGrow ? @"YES" : @"NO";
      break;
    case ASLayoutElementPropertyFlexShrink:
      valueString = layoutElement.style.flexShrink ? @"YES" : @"NO";
      break;
    case ASLayoutElementPropertyAlignSelf:
      valueString = [ASLayoutElementInspectorCell alignSelfEnumValueString:layoutElement.style.alignSelf];
      break;
    case ASLayoutElementPropertyFlexBasis:
      if (layoutElement.style.flexBasis.unit && layoutElement.style.flexBasis.value) {  // ENUM TYPE
        valueString = [NSString stringWithFormat:@"%0.0f %@", layoutElement.style.flexBasis.value,
                       [ASLayoutElementInspectorCell ASRelativeDimensionEnumString:layoutElement.style.alignSelf]];
      } else {
        valueString = @"0 pts";
      }
      break;
    case ASLayoutElementPropertySpacingBefore:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutElement.style.spacingBefore];
      break;
    case ASLayoutElementPropertySpacingAfter:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutElement.style.spacingAfter];
      break;
    case ASLayoutElementPropertyAscender:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutElement.style.ascender];
      break;
    case ASLayoutElementPropertyDescender:
      valueString = [NSString stringWithFormat:@"%0.0f", layoutElement.style.descender];
      break;
    default:
      valueString = @"?";
      break;
  }
  return [ASLayoutElementInspectorCell attributedStringFromString:valueString];
}

+ (NSAttributedString *)propertyValueDetailAttributedStringForProperty:(ASLayoutElementPropertyType)property withLayoutElement:(id<ASLayoutElement>)layoutElement
{
  NSString *valueString;
  
  switch (property) {
    case ASLayoutElementPropertyFlexGrow:
    case ASLayoutElementPropertyFlexShrink:
    case ASLayoutElementPropertyAlignSelf:
    case ASLayoutElementPropertyFlexBasis:
    case ASLayoutElementPropertySpacingBefore:
    case ASLayoutElementPropertySpacingAfter:
    case ASLayoutElementPropertyAscender:
    case ASLayoutElementPropertyDescender:
    default:
      return nil;
  }
  return [ASLayoutElementInspectorCell attributedStringFromString:valueString];
}

- (void)endEditingValue
{
  _textBubble = nil;
  __currentlyOpenedCell = nil;
  _buttonNode.selected = NO;
  [self setNeedsLayout];
}

- (void)beginEditingValue
{
  _textBubble.delegate = self;
  __currentlyOpenedCell = self;
  [self setNeedsLayout];
}

- (void)valueChangedToIndex:(NSUInteger)index
{
  switch (_propertyType) {
      
    case ASLayoutElementPropertyAlignSelf:
      _layoutElementToEdit.style.alignSelf = index;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[ASLayoutElementInspectorCell alignSelfEnumValueString:index]];
      break;

    case ASLayoutElementPropertySpacingBefore:
      _layoutElementToEdit.style.spacingBefore = (CGFloat)index;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.spacingBefore]];
      break;

    case ASLayoutElementPropertySpacingAfter:
      _layoutElementToEdit.style.spacingAfter = (CGFloat)index;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.spacingAfter]];
      break;

    case ASLayoutElementPropertyAscender:
      _layoutElementToEdit.style.ascender = (CGFloat)index;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.ascender]];
      break;
      
    case ASLayoutElementPropertyDescender:
      _layoutElementToEdit.style.descender = (CGFloat)index;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.descender]];
      break;
      
    default:
      break;
  }
  
  [self setNeedsLayout];
}

#pragma mark - gesture handling

- (void)buttonTapped:(ASButtonNode *)sender
{
  BOOL selfIsEditing = (self == __currentlyOpenedCell);
  [__currentlyOpenedCell endEditingValue];
  if (selfIsEditing) {
    sender.selected = NO;
    return;
  }
  
//  NSUInteger currentAlignSelfValue;
//  NSUInteger nextAlignSelfValue;
//  CGFloat    newValue;

  sender.selected = !sender.selected;
  switch (_propertyType) {
      
    case ASLayoutElementPropertyFlexGrow:
      _layoutElementToEdit.style.flexGrow = sender.isSelected ? 1.0 : 0.0;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutElementPropertyFlexShrink:
      _layoutElementToEdit.style.flexShrink = sender.isSelected ? 1.0 : 0.0;
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutElementPropertyAlignSelf:
      _textBubble = [[ASLayoutElementInspectorCellEditingBubble alloc] initWithEnumOptions:YES
                                                                            enumStrings:[ASLayoutElementInspectorCell alignSelfEnumStringArray]
                                                                     currentOptionIndex:_layoutElementToEdit.style.alignSelf];

      [self beginEditingValue];
//      if ([self layoutSpec]) {
//        currentAlignSelfValue = [[self layoutSpec] alignSelf];
//        nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
//        [[self layoutSpec] setAlignSelf:nextAlignSelfValue];
//    
//      } else if ([self node]) {
//        currentAlignSelfValue = [[self node] alignSelf];
//        nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
//        [[self node] setAlignSelf:nextAlignSelfValue];
//      }
      break;

    case ASLayoutElementPropertySpacingBefore:
      _textBubble = [[ASLayoutElementInspectorCellEditingBubble alloc] initWithSliderMinValue:0 maxValue:100 currentValue:_layoutElementToEdit.style.spacingBefore];
      [self beginEditingValue];
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.spacingBefore]];
      break;

    case ASLayoutElementPropertySpacingAfter:
      _textBubble = [[ASLayoutElementInspectorCellEditingBubble alloc] initWithSliderMinValue:0 maxValue:100 currentValue:_layoutElementToEdit.style.spacingAfter];
      [self beginEditingValue];
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.spacingAfter]];
      break;


    case ASLayoutElementPropertyAscender:
      _textBubble = [[ASLayoutElementInspectorCellEditingBubble alloc] initWithSliderMinValue:0 maxValue:100 currentValue:_layoutElementToEdit.style.ascender];
      [self beginEditingValue];
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.ascender]];
      break;

    case ASLayoutElementPropertyDescender:
      _textBubble = [[ASLayoutElementInspectorCellEditingBubble alloc] initWithSliderMinValue:0 maxValue:100 currentValue:_layoutElementToEdit.style.descender];
      [self beginEditingValue];
      _textNode.attributedText = [ASLayoutElementInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutElementToEdit.style.descender]];
      break;
      
    default:
      break;
  }
  [self setNeedsLayout];
}

#pragma mark - cast layoutElementToEdit

- (ASDisplayNode *)node
{
  if (_layoutElementToEdit.layoutElementType == ASLayoutElementTypeDisplayNode) {
    return (ASDisplayNode *)_layoutElementToEdit;
  }
  return nil;
}

- (ASLayoutSpec *)layoutSpec
{
  if (_layoutElementToEdit.layoutElementType == ASLayoutElementTypeLayoutSpec) {
    return (ASLayoutSpec *)_layoutElementToEdit;
  }
  return nil;
}

#pragma mark - data / property type helper methods

+ (CellDataType)dataTypeForProperty:(ASLayoutElementPropertyType)property
{
  switch (property) {
      
    case ASLayoutElementPropertyFlexGrow:
    case ASLayoutElementPropertyFlexShrink:
      return CellDataTypeBool;
      
    case ASLayoutElementPropertySpacingBefore:
    case ASLayoutElementPropertySpacingAfter:
    case ASLayoutElementPropertyAscender:
    case ASLayoutElementPropertyDescender:
      return CellDataTypeFloat;
      
    default:
      break;
  }
  return CellDataTypeBool;
}

+ (NSString *)propertyStringForPropertyType:(ASLayoutElementPropertyType)property
{
  NSString *string;
  switch (property) {
    case ASLayoutElementPropertyFlexGrow:
      string = @"FlexGrow";
      break;
    case ASLayoutElementPropertyFlexShrink:
      string = @"FlexShrink";
      break;
    case ASLayoutElementPropertyAlignSelf:
      string = @"AlignSelf";
      break;
    case ASLayoutElementPropertyFlexBasis:
      string = @"FlexBasis";
      break;
    case ASLayoutElementPropertySpacingBefore:
      string = @"SpacingBefore";
      break;
    case ASLayoutElementPropertySpacingAfter:
      string = @"SpacingAfter";
      break;
    case ASLayoutElementPropertyAscender:
      string = @"Ascender";
      break;
    case ASLayoutElementPropertyDescender:
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

+ (NSString *)alignSelfEnumValueString:(NSUInteger)type
{
  return [[self class] alignSelfTypeNames][@(type)];
}

+ (NSArray <NSString *> *)alignSelfEnumStringArray
{
  return @[@"ASStackLayoutAlignSelfAuto",
           @"ASStackLayoutAlignSelfStart",
           @"ASStackLayoutAlignSelfEnd",
           @"ASStackLayoutAlignSelfCenter",
           @"ASStackLayoutAlignSelfStretch"];
}

+ (NSDictionary *)ASRelativeDimensionTypeNames
{
  return @{@(ASDimensionUnitPoints) : @"pts",
           @(ASDimensionUnitFraction) : @"%"};
}

+ (NSString *)ASRelativeDimensionEnumString:(NSUInteger)type
{
  return [[self class] ASRelativeDimensionTypeNames][@(type)];
}

#pragma mark - formatting helper methods

+ (NSAttributedString *)attributedStringFromString:(NSString *)string
{
  return [ASLayoutElementInspectorCell attributedStringFromString:string withTextColor:[UIColor whiteColor]];
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
  UIImage *orangeStretchBtnImg = [ASLayoutElementInspectorCell imageForButtonWithBackgroundColor:orangeColor
                                                                                  borderColor:[UIColor whiteColor]
                                                                                  borderWidth:3];
  UIImage *greyStretchBtnImg = [ASLayoutElementInspectorCell imageForButtonWithBackgroundColor:[UIColor darkGrayColor]
                                                                                borderColor:[UIColor lightGrayColor]
                                                                                borderWidth:3];
  UIImage *clearStretchBtnImg = [ASLayoutElementInspectorCell imageForButtonWithBackgroundColor:[UIColor clearColor]
                                                                                 borderColor:[UIColor whiteColor]
                                                                                 borderWidth:3];
  ASButtonNode *btn = [[ASButtonNode alloc] init];
  btn.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
  [btn setAttributedTitle:[ASLayoutElementInspectorCell attributedStringFromString:title] forState:ASControlStateNormal];
  [btn setAttributedTitle:[ASLayoutElementInspectorCell attributedStringFromString:title withTextColor:[UIColor lightGrayColor]] forState:ASControlStateDisabled];
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



@implementation ASLayoutElementInspectorCellEditingBubble
{
  NSMutableArray<ASButtonNode *> *_textNodes;
  ASDisplayNode                  *_slider;
}

- (instancetype)initWithEnumOptions:(BOOL)yes enumStrings:(NSArray<NSString *> *)options currentOptionIndex:(NSUInteger)currentOption
{
  self = [super init];
  if (self) {
    self.automaticallyManagesSubnodes = YES;
    self.backgroundColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    
    _textNodes = [[NSMutableArray alloc] init];
    int index = 0;
    for (NSString *optionStr in options) {
      ASButtonNode *btn = [[ASButtonNode alloc] init];
      [btn setAttributedTitle:[ASLayoutElementInspectorCell attributedStringFromString:optionStr] forState:ASControlStateNormal];
      [btn setAttributedTitle:[ASLayoutElementInspectorCell attributedStringFromString:optionStr withTextColor:[UIColor redColor]]
                     forState:ASControlStateSelected];
      [btn addTarget:self action:@selector(enumOptionSelected:) forControlEvents:ASControlNodeEventTouchUpInside];
      btn.selected = (index == currentOption) ? YES : NO;
      [_textNodes addObject:btn];
      index++;
    }
  }
  return self;
}

- (instancetype)initWithSliderMinValue:(CGFloat)min maxValue:(CGFloat)max currentValue:(CGFloat)current
{
  if (self = [super init]) {
    self.userInteractionEnabled = YES;
    self.automaticallyManagesSubnodes = YES;
    self.backgroundColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    
    __weak id weakSelf = self;
    _slider = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
      UISlider *slider = [[UISlider alloc] init];
      slider.minimumValue = min;
      slider.maximumValue = max;
      slider.value = current;
      [slider addTarget:weakSelf action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
      
      return slider;
    }];
    _slider.userInteractionEnabled = YES;
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  _slider.style.preferredSize = CGSizeMake(constrainedSize.max.width, 25);
  
  NSMutableArray *children = [[NSMutableArray alloc] init];
  if (_textNodes) {
    ASStackLayoutSpec *textStack = [ASStackLayoutSpec verticalStackLayoutSpec];
    textStack.children = _textNodes;
    textStack.spacing = 2;
    [children addObject:textStack];
  }
  if (_slider) {
    _slider.style.flexGrow = 1.0;
    [children addObject:_slider];
  }
  
  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackSpec.children = children;
  verticalStackSpec.spacing = 2;
  verticalStackSpec.style.flexGrow = 1.0;
  verticalStackSpec.style.alignSelf = ASStackLayoutAlignSelfStretch;
  
  ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(8, 8, 8, 8) child:verticalStackSpec];
  
  return insetSpec;
}

#pragma mark - gesture handling
- (void)enumOptionSelected:(ASButtonNode *)sender
{
  sender.selected = !sender.selected;
  for (ASButtonNode *node in _textNodes) {
    if (node != sender) {
      node.selected = NO;
    }
  }
  [self.delegate valueChangedToIndex:[_textNodes indexOfObject:sender]];
  [self setNeedsLayout];
}

- (void)sliderValueChanged:(UISlider *)sender
{
  [self.delegate valueChangedToIndex:roundf(sender.value)];
}

@end


