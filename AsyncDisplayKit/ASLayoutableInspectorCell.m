//
//  ASLayoutableInspectorCell.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorCell.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

typedef NS_ENUM(NSInteger, CellDataType) {
  CellDataTypeBool,
  CellDataTypeFloat,
};

__weak static ASLayoutableInspectorCell *__currentlyOpenedCell = nil;

@protocol InspectorCellEditingBubbleProtocol <NSObject>
- (void)valueChangedToIndex:(NSUInteger)index;
@end

@interface ASLayoutableInspectorCellEditingBubble : ASDisplayNode
@property (nonatomic, strong, readwrite) id<InspectorCellEditingBubbleProtocol> delegate;
- (instancetype)initWithOptions:(NSArray<NSString *> *)options;
@end

@interface ASLayoutableInspectorCell () <InspectorCellEditingBubbleProtocol>
@end

@implementation ASLayoutableInspectorCell
{
  ASLayoutablePropertyType      _propertyType;
  CellDataType                  _dataType;
  id<ASLayoutable>              _layoutableToEdit;
  
  ASButtonNode                  *_buttonNode;
  ASTextNode                    *_textNode;
  ASTextNode                    *_textNode2;
  
  ASLayoutableInspectorCellEditingBubble *_textBubble;
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
    
    _textNode2 = [[ASTextNode alloc] init];
    _textNode2.attributedString = [ASLayoutableInspectorCell propertyValueDetailAttributedStringForProperty:property withLayoutable:layoutable];
    
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *horizontalSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalSpec.children           = @[_buttonNode, _textNode];
  horizontalSpec.flexGrow           = YES;
  horizontalSpec.alignItems         = ASStackLayoutAlignItemsCenter;
  horizontalSpec.justifyContent     = ASStackLayoutJustifyContentSpaceBetween;
  
  ASLayoutSpec *childSpec;
  if (_textBubble) {
    ASStackLayoutSpec *verticalSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
    verticalSpec.children           = @[horizontalSpec, _textBubble];
    verticalSpec.spacing            = 8;
    verticalSpec.flexGrow           = YES;
    _textBubble.flexGrow            = YES;
    childSpec = verticalSpec;
  } else {
    childSpec = horizontalSpec;
  }
  ASInsetLayoutSpec *insetSpec      = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(2, 4, 2, 4) child:childSpec];
  insetSpec.flexGrow = YES;
  
  return insetSpec;
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
      valueString = [ASLayoutableInspectorCell alignSelfEnumValueString:layoutable.alignSelf];
      break;
    case ASLayoutablePropertyFlexBasis:
      if (layoutable.flexBasis.type && layoutable.flexBasis.value) {  // ENUM TYPE
        valueString = [NSString stringWithFormat:@"%0.0f %@", layoutable.flexBasis.value,
                       [ASLayoutableInspectorCell ASRelativeDimensionEnumString:layoutable.alignSelf]];
      } else {
        valueString = @"0 pts";
      }
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

+ (NSAttributedString *)propertyValueDetailAttributedStringForProperty:(ASLayoutablePropertyType)property withLayoutable:(id<ASLayoutable>)layoutable
{
  NSString *valueString;
  
  switch (property) {
    case ASLayoutablePropertyFlexGrow:
    case ASLayoutablePropertyFlexShrink:
    case ASLayoutablePropertyAlignSelf:
    case ASLayoutablePropertyFlexBasis:
    case ASLayoutablePropertySpacingBefore:
    case ASLayoutablePropertySpacingAfter:
    case ASLayoutablePropertyAscender:
    case ASLayoutablePropertyDescender:
    default:
      return nil;
  }
  return [ASLayoutableInspectorCell attributedStringFromString:valueString];
}

- (void)endEditingValue
{
  _textBubble = nil;
  __currentlyOpenedCell = nil;
  [self setNeedsLayout];
}

- (void)beginEditingValueWithOptions:(NSArray<NSString *> *)optionStrings
{
  _textBubble = [[ASLayoutableInspectorCellEditingBubble alloc] initWithOptions:optionStrings];
  _textBubble.delegate = self;
  __currentlyOpenedCell = self;
  [self setNeedsLayout];
}

- (void)valueChangedToIndex:(NSUInteger)index
{
  [_layoutableToEdit setDescender:(CGFloat)index];
  _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutableToEdit.descender]];
  [self setNeedsLayout];
}

#pragma mark - gesture handling

- (void)buttonTapped:(ASButtonNode *)sender
{
  BOOL selfIsEditing = (self == __currentlyOpenedCell);
  [__currentlyOpenedCell endEditingValue];
  if (selfIsEditing) {
    return;
  }
  
//  NSUInteger currentAlignSelfValue;
//  NSUInteger nextAlignSelfValue;
  CGFloat    newValue;
  
  switch (_propertyType) {
      
    case ASLayoutablePropertyFlexGrow:
      [_layoutableToEdit setFlexGrow:!sender.isSelected];
      sender.selected            = !sender.selected;
      _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutablePropertyFlexShrink:
      [_layoutableToEdit setFlexShrink:!sender.isSelected];
      sender.selected            = !sender.selected;
      _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:sender.selected ? @"YES" : @"NO"];
      break;
      
    case ASLayoutablePropertyAlignSelf:
      [self beginEditingValueWithOptions:[ASLayoutableInspectorCell alignSelfEnumStringArray]];  // FIXME: also set selected
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
      
    case ASLayoutablePropertyDescender:
      [self beginEditingValueWithOptions:@[]];
      newValue = 5;
      [_layoutableToEdit setDescender:newValue];
      // update .selected & value
      sender.selected            = !sender.selected;
      _textNode.attributedString = [ASLayoutableInspectorCell attributedStringFromString:[NSString stringWithFormat:@"%0.0f", _layoutableToEdit.descender]];
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
    case ASLayoutablePropertyFlexBasis:
      string = @"FlexBasis";
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
  return @{@(ASRelativeDimensionTypePoints) : @"pts",
           @(ASRelativeDimensionTypePercent) : @"%"};
}

+ (NSString *)ASRelativeDimensionEnumString:(NSUInteger)type
{
  return [[self class] ASRelativeDimensionTypeNames][@(type)];
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





@implementation ASLayoutableInspectorCellEditingBubble
{
  NSMutableArray<ASButtonNode *> *_textNodes;
}

- (instancetype)initWithOptions:(NSArray<NSString *> *)options
{
  self = [super init];
  if (self) {
    self.usesImplicitHierarchyManagement = YES;
    self.backgroundColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
    
    _textNodes = [[NSMutableArray alloc] init];
    for (NSString *optionStr in options) {
      ASButtonNode *btn = [[ASButtonNode alloc] init];
      [btn setAttributedTitle:[ASLayoutableInspectorCell attributedStringFromString:optionStr] forState:ASControlStateNormal];
      [btn setAttributedTitle:[ASLayoutableInspectorCell attributedStringFromString:optionStr withTextColor:[UIColor redColor]]
                     forState:ASControlStateSelected];
      [btn addTarget:self action:@selector(tapped:) forControlEvents:ASControlNodeEventTouchUpInside];
      [_textNodes addObject:btn];
    }
  }
  return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *verticalStackSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStackSpec.children = _textNodes;
  verticalStackSpec.spacing = 2;
  
  ASInsetLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(8, 8, 8, 8) child:verticalStackSpec];
  
  return insetSpec;
}

- (void)tapped:(ASButtonNode *)sender
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

@end


