//
//  ASLayoutableInspectorNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorNode.h"
#import "ASDisplayNode+Beta.h"
#import "ASLayoutSpec+Debug.h"


@interface ASLayoutableInspectorNode ()
@end

@implementation ASLayoutableInspectorNode
{
  // Navigate layout hierarchy
  ASButtonNode *_parentNodeNavBtn;
  ASButtonNode *_siblingNodeRightNavBtn;
  ASButtonNode *_siblingNodeLefttNavBtn;
  ASButtonNode *_childNodeNavBtn;
  
  // Item properties
  ASTextNode   *_itemPropertiesSectionTitle;
  ASTextNode   *_itemDescription;
  ASButtonNode *_itemBackgroundColorBtn;
  
  // <Layoutable> properites
  ASTextNode   *_layoutablePropertiesSectionTitle;
  ASButtonNode *_flexGrowBtn;
  ASButtonNode *_flexShrinkBtn;
  ASButtonNode *_flexBasisBtn;
  ASButtonNode *_alignSelfBtn;
  ASButtonNode *_spacingBeforeBtn;
  ASButtonNode *_spacingAfterBtn;
  ASButtonNode *_alignItemsBtn;
  
  ASTextNode *_flexGrowValue;
  ASTextNode *_flexShrinkValue;
  ASTextNode *_flexBasisValue;
  ASTextNode *_alignSelfValue;
  ASTextNode *_spacingBeforeValue;
  ASTextNode *_spacingAfterValue;
  
  ASDisplayNode *_slider;
  
  // LayoutSpec properties
  ASTextNode *_layoutSpecPropertiesSectionTitle;
  
  
  

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
    
//    _tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
//    _tableNode.dataSource = self;
    
    //    self.backgroundColor = [UIColor colorWithRed:40/255.0 green:43/255.0 blue:53/255.0 alpha:1.0];
    
    _itemDescription = [[ASTextNode alloc] init];
    _layoutablePropertiesSectionTitle = [[ASTextNode alloc] init];
    _layoutablePropertiesSectionTitle.attributedString = [self attributedStringFromString:@"<Layoutable> Properties"];
    _layoutSpecPropertiesSectionTitle = [[ASTextNode alloc] init];
    _layoutSpecPropertiesSectionTitle.attributedString = [self attributedStringFromString:@"<LayoutSpec> Properties"];
    
    _flexGrowBtn = [self makeBtnNodeWithTitle:@"flexGrow"];
    [_flexGrowBtn addTarget:self action:@selector(setFlexGrowValue:) forControlEvents:ASControlNodeEventTouchUpInside];
    _flexGrowValue = [[ASTextNode alloc] init];
    
    _flexShrinkBtn = [self makeBtnNodeWithTitle:@"flexShrink"];
    [_flexShrinkBtn addTarget:self action:@selector(setFlexShrinkValue:) forControlEvents:ASControlNodeEventTouchUpInside];
    _flexShrinkValue = [[ASTextNode alloc] init];
    
    _flexBasisBtn = [self makeBtnNodeWithTitle:@"flexBasis"];
    _flexBasisValue = [[ASTextNode alloc] init];
    
    _alignSelfBtn = [self makeBtnNodeWithTitle:@"alignSelf"];
    [_alignSelfBtn addTarget:self action:@selector(setAlignSelfValue:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _alignItemsBtn = [self makeBtnNodeWithTitle:@"alignItems"];
    [_alignItemsBtn addTarget:self action:@selector(setAlignItemsValue:) forControlEvents:ASControlNodeEventTouchUpInside];

    _itemBackgroundColorBtn = [self makeBtnNodeWithTitle:@"node color"];
    [_itemBackgroundColorBtn addTarget:self action:@selector(changeColor:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    _parentNodeNavBtn = [self makeBtnNodeWithTitle:@"parent node"];
    _siblingNodeRightNavBtn = [self makeBtnNodeWithTitle:@"sibling node"];
    _siblingNodeLefttNavBtn = [self makeBtnNodeWithTitle:@"sibling node"];
    _childNodeNavBtn = [self makeBtnNodeWithTitle:@"child node"];
    
    _slider = [[ASDisplayNode alloc] initWithViewBlock:^UIView * _Nonnull{
                UISlider *slider = [[UISlider alloc] init];
                return slider;
              }];

    [self setUpInspectorForLayoutableType];
  }
  return self;
}

- (void)layout
{
  [super layout];
  
//  _tableNode.frame = self.bounds;
}

- (ASButtonNode *)makeBtnNodeWithTitle:(NSString *)title
{
  UIColor *orangeColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
  UIImage *orangeStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:orangeColor
                                                                                  borderColor:[UIColor whiteColor]
                                                                                  borderWidth:3];
  UIImage *greyStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:[UIColor lightGrayColor]
                                                                                borderColor:[UIColor whiteColor]
                                                                                borderWidth:3];
  UIImage *clearStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:[UIColor clearColor]
                                                                                borderColor:[UIColor whiteColor]
                                                                                borderWidth:3];
  ASButtonNode *btn = [[ASButtonNode alloc] init];
  btn.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
  [btn setAttributedTitle:[self attributedStringFromString:title] forState:ASControlStateNormal];
  [btn setBackgroundImage:clearStretchBtnImg forState:ASControlStateNormal];
  [btn setBackgroundImage:orangeStretchBtnImg forState:ASControlStateSelected];
  [btn setBackgroundImage:greyStretchBtnImg forState:ASControlStateDisabled];

  return btn;
}

- (void)setLayoutableToEdit:(id<ASLayoutable>)layoutableToEdit
{
  // show master split view controller
//  self.supernode.splitViewController.viewControllers[1]
  
  [self.delegate shouldShowMasterSplitViewController];
  
  if (_layoutableToEdit != layoutableToEdit) {
    _layoutableToEdit = layoutableToEdit;
    _itemDescription.attributedString = [self attributedStringFromLayoutable:_layoutableToEdit];
    
    [self updateInspectorViewWithLayoutable];
    [self setUpInspectorForLayoutableType];
    
//    UIWindow *keyWindow = [[NSClassFromString(@"UIApplication") sharedApplication] keyWindow];
//    CGSize windowSize = keyWindow.bounds.size;

    if (layoutableToEdit) {
      
      
      
//      _nodeDescription.attributedString = [self attributedStringFromLayoutable:_layoutableToEdit];
//      
//      // present inspectorView
//      self.frame = CGRectMake(0, windowSize.height, windowSize.width, windowSize.height / 3.0);
//      [self measureWithSizeRange:ASSizeRangeMakeExactSize(self.bounds.size)];
//      [keyWindow addSubnode:self];
//      [UIView animateWithDuration:0.2 animations:^{
//        CGRect rect = self.frame;
//        rect.origin.y -= rect.size.height;
//        self.frame = rect;
//      }];
//      
//    } else {
//      
//      // hide inspector
//      CGRect finalRect = CGRectMake(0, windowSize.height, windowSize.width, windowSize.height / 3.0);
//      [keyWindow addSubnode:self];
//      [UIView animateWithDuration:0.2 animations:^{
//        self.frame = finalRect;
//      } completion:^(BOOL finished) {
//        [self removeFromSupernode];
//      }];
    }
  }
}



// FIXME: way to manually disable on a sublayout tree

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *horizontalStackNav = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStackNav.flexGrow = YES;
  horizontalStackNav.children = @[_siblingNodeLefttNavBtn, _siblingNodeRightNavBtn];
  
  ASStackLayoutSpec *horizontalStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack.flexGrow = YES;
  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
  spacer.flexGrow = YES;
  horizontalStack.children = @[_flexGrowBtn, spacer, _flexGrowValue];
  _flexGrowValue.alignSelf = ASStackLayoutAlignSelfEnd;       // FIXME: framework give a warning if you use ASAlignmentBottom!!!!!
  
  ASStackLayoutSpec *horizontalStack2 = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack2.flexGrow = YES;
  horizontalStack2.children = @[_flexShrinkBtn, spacer, _flexShrinkValue];
  _flexShrinkValue.alignSelf = ASStackLayoutAlignSelfEnd;
  
  ASStackLayoutSpec *horizontalStack3 = [ASStackLayoutSpec horizontalStackLayoutSpec];
  horizontalStack3.flexGrow = YES;
  horizontalStack3.children = @[_flexBasisBtn, spacer, _flexBasisValue];
  _flexBasisValue.alignSelf = ASStackLayoutAlignSelfEnd;

  ASStackLayoutSpec *verticalLayoutableStack = [ASStackLayoutSpec verticalStackLayoutSpec];
  verticalLayoutableStack.flexGrow = YES;
  verticalLayoutableStack.spacing = 5;
  verticalLayoutableStack.children = @[_slider, _parentNodeNavBtn, horizontalStackNav, _childNodeNavBtn, _itemDescription, _itemBackgroundColorBtn, _layoutablePropertiesSectionTitle, horizontalStack, horizontalStack2, horizontalStack3, _alignSelfBtn, _alignItemsBtn, _layoutSpecPropertiesSectionTitle];
  verticalLayoutableStack.alignItems = ASStackLayoutAlignItemsStretch;                // stretch headerStack to fill horizontal space

  ASLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(100, 10, 10, 10) child:verticalLayoutableStack];
  insetSpec.flexGrow = YES;
  return insetSpec;
}

- (NSAttributedString *)attributedStringFromLayoutable:(id<ASLayoutable>)layoutable
{
  if ([layoutable isKindOfClass:[ASLayoutSpec class]]) {
    return [self attributedStringFromString:[(ASLayoutSpec *)layoutable description]];
  } else if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
    return [self attributedStringFromString:[(ASControlNode *)layoutable description]];
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

- (void)updateInspectorViewWithLayoutable
{
  if ([self node]) {
    UIColor *nodeBackgroundColor = [[self node] backgroundColor];
    UIImage *colorBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:nodeBackgroundColor
                                                                            borderColor:[UIColor whiteColor]
                                                                            borderWidth:3];
    [_itemBackgroundColorBtn setBackgroundImage:colorBtnImg forState:ASControlStateNormal];
  }
  
  
//  _alignSelfBtn.selected = YES;
//  NSUInteger alignSelfValue = [(ASDisplayNode *)self.layoutableToEdit alignSelf];
//  NSString *newTitle = [@"alignSelf:" stringByAppendingString:[self typeDisplayName:alignSelfValue]];
//  [_alignSelfBtn setAttributedTitle:[self attributedStringFromString:newTitle] forState:ASControlStateNormal];

  _alignSelfBtn.selected = YES;
  NSUInteger alignSelfValue = [self.layoutableToEdit alignSelf];
  NSString *newTitle = [@"alignSelf:" stringByAppendingString:[self typeDisplayName:alignSelfValue]];
  [_alignSelfBtn setAttributedTitle:[self attributedStringFromString:newTitle] forState:ASControlStateNormal];
  
//  _alignItemsBtn.selected = YES;
//  if ([[self layoutSpec] isKindOfClass:[ASStackLayoutSpec class]]) {
//    NSUInteger alignItemsValue = [(ASStackLayoutSpec *)[self layoutSpec] alignItems];
//    newTitle = [@"alignItems:" stringByAppendingString:[self typeDisplayNameItems:alignItemsValue]];
//    [_alignItemsBtn setAttributedTitle:[self attributedStringFromString:newTitle] forState:ASControlStateNormal];
//  }
//  
//  if ([layoutable isKindOfClass:[ASLayoutSpec class]]) {
//    return [self attributedStringFromString:[(ASLayoutSpec *)layoutable asciiArtString]];
//  } else if ([layoutable isKindOfClass:[ASDisplayNode class]]) {
//    return [self attributedStringFromString:[(ASControlNode *)layoutable asciiArtString]];
//  }
  
  _flexGrowBtn.selected           = [self.layoutableToEdit flexGrow];
  _flexGrowValue.attributedString = [self attributedStringFromString: (_flexGrowBtn.selected) ? @"YES" : @"NO"];
  
  _flexShrinkBtn.selected           = self.layoutableToEdit.flexShrink;
  _flexShrinkValue.attributedString = [self attributedStringFromString: (_flexShrinkBtn.selected) ? @"YES" : @"NO"];
  
//  _flexBasisBtn.selected           = self.layoutableToEdit.flexShrink;
//  _flexBasisValue.attributedString = [self attributedStringFromString: (_flexBasisBtn.selected) ? @"YES" : @"NO"];
  
  [self setNeedsLayout];
}

- (void)setFlexGrowValue:(ASButtonNode *)sender
{
  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
  
  if ([self.layoutableToEdit isKindOfClass:[ASLayoutSpec class]]) {
    [(ASLayoutSpec *)self.layoutableToEdit setFlexGrow:sender.isSelected];
    
  } else if ([self.layoutableToEdit isKindOfClass:[ASDisplayNode class]]) {
    [(ASDisplayNode *)self.layoutableToEdit setFlexGrow:sender.isSelected];
  }
  [self updateInspectorViewWithLayoutable];
}

- (void)setFlexShrinkValue:(ASButtonNode *)sender
{
  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
  
  [(ASDisplayNode *)self.layoutableToEdit setFlexShrink:sender.isSelected];
  
  [self updateInspectorViewWithLayoutable];
}

+ (NSDictionary *)typeDisplayNames
{
  return @{@(ASStackLayoutAlignSelfAuto) : @"Auto",
           @(ASStackLayoutAlignSelfStart) : @"Start",
           @(ASStackLayoutAlignSelfEnd) : @"End",
           @(ASStackLayoutAlignSelfCenter) : @"Center",
           @(ASStackLayoutAlignSelfStretch) : @"Stretch"};
}

- (NSString *)typeDisplayName:(NSUInteger)type
{
  return [[self class] typeDisplayNames][@(type)];
}

- (void)setAlignSelfValue:(ASButtonNode *)sender
{
  NSUInteger nodeAlignSelfValue = [(ASDisplayNode *)self.layoutableToEdit alignSelf];

  NSUInteger nextAlignSelfValue = (nodeAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? nodeAlignSelfValue + 1 : 0;
  
  [(ASDisplayNode *)self.layoutableToEdit setAlignSelf:nextAlignSelfValue];
  [(ASDisplayNode *)self.layoutableToEdit setNeedsLayout];
  
  [self updateInspectorViewWithLayoutable];
}

+ (NSDictionary *)typeDisplayNamesItems
{
  return @{@(ASStackLayoutAlignItemsBaselineFirst) : @"BaselineFirst",
           @(ASStackLayoutAlignItemsBaselineLast) : @"BaselineLast",
           @(ASStackLayoutAlignItemsCenter) : @"Center",
           @(ASStackLayoutAlignItemsEnd) : @"End",
           @(ASStackLayoutAlignItemsStart) : @"Start",
           @(ASStackLayoutAlignItemsStretch) : @"Stretch"};
}

- (NSString *)typeDisplayNameItems:(NSUInteger)type
{
  return [[self class] typeDisplayNamesItems][@(type)];
}

- (void)setAlignItemsValue:(ASButtonNode *)sender
{
  NSUInteger alignItemsValue = [(ASStackLayoutSpec *)[(ASLayoutSpecVisualizerNode *)self.layoutableToEdit layoutSpec] alignItems];
  
  NSUInteger nextAlignItemsValue = (alignItemsValue + 1 <= ASStackLayoutAlignItemsBaselineLast) ? alignItemsValue + 1 : 0;
  
  [(ASStackLayoutSpec *)[(ASLayoutSpecVisualizerNode *)self.layoutableToEdit layoutSpec] setAlignItems:nextAlignItemsValue];
  [(ASLayoutSpecVisualizerNode *)self.layoutableToEdit setNeedsLayout];

  [self updateInspectorViewWithLayoutable];
}

- (void)changeColor:(ASButtonNode *)sender
{
  NSArray *colorArray = @[[UIColor orangeColor],
                          [UIColor redColor],
                          [UIColor greenColor],
                          [UIColor purpleColor]];
  
  UIColor *nodeBackgroundColor = [(ASDisplayNode *)self.layoutableToEdit backgroundColor];
  
  NSUInteger colorIndex = [colorArray indexOfObject:nodeBackgroundColor];
  colorIndex = (colorIndex + 1 < [colorArray count]) ? colorIndex + 1 : 0;
  
  [(ASDisplayNode *)self.layoutableToEdit setBackgroundColor: [colorArray objectAtIndex:colorIndex]];
  
  [self updateInspectorViewWithLayoutable];
}

//
//- (void)setFlexBasisValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//
//  // FIXME: finish
//}

- (void)setUpInspectorForLayoutableType
{
  [self.layoutableToEdit respondsToSelector:@selector(flexGrow)];
  
  if (!self.layoutableToEdit) {
  
    _itemBackgroundColorBtn.enabled = NO;
    _flexGrowBtn.enabled        = NO;
    _flexShrinkBtn.enabled      = NO;
    _flexBasisBtn.enabled       = NO;
    _alignSelfBtn.enabled       = NO;
    _spacingBeforeBtn.enabled   = NO;
    _spacingAfterBtn.enabled    = NO;
    _alignItemsBtn.enabled      = NO;
    
  } else if ([self layoutableIsASLayoutSpec]) {   // maybe make an enum type?
  
    _itemBackgroundColorBtn.enabled = YES;
    _flexGrowBtn.enabled        = YES;
    _flexShrinkBtn.enabled      = YES;
    _flexBasisBtn.enabled       = YES;
    _alignSelfBtn.enabled       = YES;
    _spacingBeforeBtn.enabled   = YES;
    _spacingAfterBtn.enabled    = YES;
    _alignItemsBtn.enabled      = YES;
    
  } else if ([self layoutableIsASDisplayNode]) {
    
    _itemBackgroundColorBtn.enabled = YES;
    _flexGrowBtn.enabled        = YES;
    _flexShrinkBtn.enabled      = YES;
    _flexBasisBtn.enabled       = YES;
    _alignSelfBtn.enabled       = YES;
    _spacingBeforeBtn.enabled   = YES;
    _spacingAfterBtn.enabled    = YES;
    _alignItemsBtn.enabled      = NO;
  }
  
}

- (ASDisplayNode *)node
{
  if ([self.layoutableToEdit isKindOfClass:[ASDisplayNode class]]) {
    return (ASDisplayNode *)self.layoutableToEdit;
  }
  return nil;
}

- (ASLayoutSpec *)layoutSpec
{
  if ([self.layoutableToEdit isKindOfClass:[ASLayoutSpec class]]) {
    return (ASLayoutSpec *)self.layoutableToEdit;
  }
  return nil;
}

- (BOOL)layoutableIsASLayoutSpec
{
  return [self.layoutableToEdit isKindOfClass:[ASLayoutSpec class]];
}

- (BOOL)layoutableIsASDisplayNode
{
  return [self.layoutableToEdit isKindOfClass:[ASDisplayNode class]];
}


@end
