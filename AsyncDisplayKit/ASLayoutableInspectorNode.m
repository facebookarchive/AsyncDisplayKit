//
//  ASLayoutableInspectorNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorNode.h"
#import "ASDisplayNode+Beta.h"

@implementation ASLayoutableInspectorNode
{
  ASTextNode *_textNode;

  ASButtonNode *_flexGrowBtn;
  ASButtonNode *_flexShrinkBtn;
  ASButtonNode *_flexBasisBtn;
  ASButtonNode *_alignSelfBtn;
  ASButtonNode *_spacingBeforeBtn;
  ASButtonNode *_spacingAfterBtn;
  
  ASTextNode *_flexGrowValue;
  ASTextNode *_flexShrinkValue;
  ASTextNode *_flexBasisValue;
  ASTextNode *_alignSelfValue;
  ASTextNode *_spacingBeforeValue;
  ASTextNode *_spacingAfterValue;
  
//  ASTextNode
  
//  BOOL  isPresented;
//  BOOL  isAnimating;

}


+ (instancetype)sharedInstance
{
  static ASLayoutableInspectorNode *__inspector = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __inspector = [[ASLayoutableInspectorNode alloc] init];
  });
  
  return __inspector;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    
    self.usesImplicitHierarchyManagement = YES;
    
    _textNode = [[ASTextNode alloc] init];
    
    _flexGrowBtn = [self makeBtnNodeWithTitle:@"flexGrow"];
    [_flexGrowBtn addTarget:self action:@selector(setFlexGrowValue:) forControlEvents:ASControlNodeEventTouchUpInside];
    _flexGrowValue = [[ASTextNode alloc] init];
    
    _flexShrinkBtn = [self makeBtnNodeWithTitle:@"flexShrink"];
//    [_flexGrowBtn addTarget:self action:@selector(setFlexShrinkValue:) forControlEvents:ASControlNodeEventTouchUpInside];
    _flexShrinkValue = [[ASTextNode alloc] init];
    
    _flexBasisBtn = [self makeBtnNodeWithTitle:@"flexBasis"];
    _flexBasisValue = [[ASTextNode alloc] init];
    
  }
  return self;
}

- (ASButtonNode *)makeBtnNodeWithTitle:(NSString *)title
{
  UIColor *orangeColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
  UIImage *orangeStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:orangeColor
                                                                                  borderColor:[UIColor whiteColor]
                                                                                  borderWidth:3];
  UIImage *greyStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:[UIColor grayColor]
                                                                                borderColor:[UIColor whiteColor]
                                                                                borderWidth:3];
  ASButtonNode *btn = [[ASButtonNode alloc] init];
  btn.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
  [btn setAttributedTitle:[self attributedStringFromString:title] forState:ASControlStateNormal];
  [btn setBackgroundImage:greyStretchBtnImg forState:ASControlStateNormal];
  [btn setBackgroundImage:orangeStretchBtnImg forState:ASControlStateSelected];
  
  return btn;
}

- (void)setLayoutableToEdit:(id<ASLayoutable>)layoutableToEdit
{
  if (_layoutableToEdit != layoutableToEdit) {
    _layoutableToEdit = layoutableToEdit;
    _textNode.attributedString = [self attributedStringFromLayoutable:_layoutableToEdit];
    self.backgroundColor = [UIColor colorWithRed:40/255.0 green:43/255.0 blue:53/255.0 alpha:1.0];
    
    [self updateInspectorViewWithLayoutable:layoutableToEdit];
    
    UIWindow *keyWindow = [[NSClassFromString(@"UIApplication") sharedApplication] keyWindow];
    CGSize windowSize = keyWindow.bounds.size;

    if (layoutableToEdit) {
      
      _textNode.attributedString = [self attributedStringFromLayoutable:_layoutableToEdit];
      
      // present inspectorView
      self.frame = CGRectMake(0, windowSize.height, windowSize.width, windowSize.height / 3.0);
      [self measureWithSizeRange:ASSizeRangeMakeExactSize(self.bounds.size)];
      [keyWindow addSubnode:self];
      [UIView animateWithDuration:0.2 animations:^{
        CGRect rect = self.frame;
        rect.origin.y -= rect.size.height;
        self.frame = rect;
      }];
      
    } else {
      
      // hide inspector
      CGRect finalRect = CGRectMake(0, windowSize.height, windowSize.width, windowSize.height / 3.0);
      [keyWindow addSubnode:self];
      [UIView animateWithDuration:0.2 animations:^{
        self.frame = finalRect;
      } completion:^(BOOL finished) {
        [self removeFromSupernode];
      }];
    }
  }
}

- (void)updateInspectorViewWithLayoutable:(id<ASLayoutable>)layoutableToEdit
{
  _flexGrowBtn.selected           = layoutableToEdit.flexGrow;
  _flexGrowValue.attributedString = [self attributedStringFromString: (_flexGrowBtn.selected) ? @"YES" : @"NO"];

  _flexShrinkBtn.selected           = layoutableToEdit.flexShrink;
  _flexShrinkValue.attributedString = [self attributedStringFromString: (_flexShrinkBtn.selected) ? @"YES" : @"NO"];

  _flexBasisBtn.selected           = layoutableToEdit.flexShrink;
  _flexBasisValue.attributedString = [self attributedStringFromString: (_flexBasisBtn.selected) ? @"YES" : @"NO"];
  
//  _flexBasisBtn.selected = layoutableToEdit.flexBasis;
  [self setNeedsLayout];
}

// FIXME: way to manually disable on a sublayout tree

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *horizontalStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack.children = @[_flexGrowBtn, _flexGrowValue];
  _flexGrowValue.alignSelf = ASStackLayoutAlignSelfEnd;                         // FIXME: framework give a warning if you use ASAlignmentBottom!!!!!
  _flexGrowBtn.flexShrink = NO;
  
  ASStackLayoutSpec *horizontalStack2 = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack2.children = @[_flexShrinkBtn, _flexShrinkValue];
  _flexShrinkValue.alignSelf = ASStackLayoutAlignSelfEnd;
  
  ASStackLayoutSpec *horizontalStack3 = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack3.children = @[_flexBasisBtn, _flexBasisValue];
  _flexBasisValue.alignSelf = ASStackLayoutAlignSelfEnd;

  ASStackLayoutSpec *verticalStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalStack.children = @[horizontalStack, horizontalStack2, horizontalStack3];
  
  ASLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 10, 10, 10) child:verticalStack];
  return insetSpec;
}

- (NSAttributedString *)attributedStringFromLayoutable:(id<ASLayoutable>)layoutable
{
  if ([layoutable isKindOfClass:[ASLayoutSpec class]]) {
    return [self attributedStringFromString:[(ASLayoutSpec *)layoutable asciiArtString]];
  } else if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    return [self attributedStringFromString:[(ASControlNode *)layoutable asciiArtString]];
  }
  return nil;
}

- (NSAttributedString *)attributedStringFromString:(NSString *)string
{
  NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor whiteColor],
                               NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular" size:12]};
  
  return [[NSAttributedString alloc] initWithString:string attributes:attributes];
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

- (void)setFlexGrowValue:(ASButtonNode *)sender
{
  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
  
  if ([self.layoutableToEdit isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)self.layoutableToEdit setFlexGrow:!sender.isSelected];
  } else if ([self.layoutableToEdit isKindOfClass:[ASDisplayNode class]]) {
    [(ASControlNode *)self.layoutableToEdit setFlexGrow:!sender.isSelected];
  }
  [self updateInspectorViewWithLayoutable:self.layoutableToEdit];
}

//- (void)setFlexShrinkValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//  
//  [self.layoutableToEdit setFlexShrink:!sender.isSelected];
//}
//
//- (void)setFlexBasisValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//
//  // FIXME: finish
//}

@end
