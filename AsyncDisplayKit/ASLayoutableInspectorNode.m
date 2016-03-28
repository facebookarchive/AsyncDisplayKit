//
//  ASLayoutableInspectorNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutableInspectorNode.h"
#import "ASLayoutableInspectorCell.h"
#import "ASDisplayNode+Beta.h"
#import "ASLayoutSpec+Debug.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASLayoutableInspectorNode () <ASTableDelegate, ASTableDataSource>
@end

@implementation ASLayoutableInspectorNode
{
  ASTableNode  *_tableNode;
}

#pragma mark - class methods
+ (instancetype)sharedInstance
{
  static ASLayoutableInspectorNode *__inspector = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __inspector = [[ASLayoutableInspectorNode alloc] init];
  });
  
  return __inspector;
}

#pragma mark - lifecycle
- (instancetype)init
{
  self = [super init];
  if (self) {
    
    _tableNode                 = [[ASTableNode alloc] init];
    _tableNode.delegate        = self;
    _tableNode.dataSource      = self;

    [self addSubnode:_tableNode];  // required because of manual layout
  }
  return self;
}

- (void)didLoad
{
  [super didLoad];
  _tableNode.view.backgroundColor = [UIColor colorWithRed:40/255.0 green:43/255.0 blue:53/255.0 alpha:1];
  _tableNode.view.separatorStyle = UITableViewCellSeparatorStyleNone;
  _tableNode.view.allowsSelection = NO;
}

- (void)layout
{
  [super layout];
  _tableNode.frame = self.bounds;
}

- (void)setLayoutableToEdit:(id<ASLayoutable>)layoutableToEdit
{
  if (_layoutableToEdit != layoutableToEdit) {
    _layoutableToEdit = layoutableToEdit;
    
//    [self enableInspectorNodesForLayoutable];
//    [self updateInspectorWithLayoutable];
  }
  [_tableNode.view reloadData];
}

#pragma mark - ASTableDataSource

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  return [[ASLayoutableInspectorCell alloc] initWithProperty:(ASLayoutablePropertyType)indexPath.row layoutableToEdit:_layoutableToEdit];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return ASLayoutablePropertyCount;  // FIXME:
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1; // FIXME:
}


//- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
//{
//  // navigate layout hierarchy
//  
//  _parentNodeNavBtn.alignSelf = ASStackLayoutAlignSelfCenter;
//  _childNodeNavBtn.alignSelf = ASStackLayoutAlignSelfCenter;
//
//  ASStackLayoutSpec *horizontalStackNav = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStackNav.flexGrow = YES;
//  horizontalStackNav.alignSelf = ASStackLayoutAlignSelfCenter;
//  horizontalStackNav.children = @[_siblingNodeLefttNavBtn, _siblingNodeRightNavBtn];
//  
//  ASStackLayoutSpec *horizontalStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack.flexGrow = YES;
//  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
//  
//  spacer.flexGrow = YES;
//  horizontalStack.children = @[_flexGrowBtn, spacer];
//  _flexGrowValue.alignSelf = ASStackLayoutAlignSelfEnd;      // FIXME: make framework give a warning if you use ASAlignmentBottom!!!!!
//  
//  ASStackLayoutSpec *horizontalStack2 = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack2.flexGrow = YES;
//  horizontalStack2.children = @[_flexShrinkBtn, spacer];
//  _flexShrinkValue.alignSelf = ASStackLayoutAlignSelfEnd;
//  
//  ASStackLayoutSpec *horizontalStack3 = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack3.flexGrow = YES;
//  horizontalStack3.children = @[_flexBasisBtn, spacer, _flexBasisValue];
//  _flexBasisValue.alignSelf = ASStackLayoutAlignSelfEnd;
//  
//  ASStackLayoutSpec *itemDescriptionStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  itemDescriptionStack.children = @[_itemDescription];
//  itemDescriptionStack.spacing = 5;
//  itemDescriptionStack.flexGrow = YES;
//  
//  ASStackLayoutSpec *layoutableStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  layoutableStack.children = @[_layoutablePropertiesSectionTitle, horizontalStack, horizontalStack2, horizontalStack3, _alignSelfBtn];
//  layoutableStack.spacing = 5;
//  layoutableStack.flexGrow = YES;
//  
//  ASStackLayoutSpec *layoutSpecStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  layoutSpecStack.children = @[_layoutSpecPropertiesSectionTitle, _alignItemsBtn];
//  layoutSpecStack.spacing = 5;
//  layoutSpecStack.flexGrow = YES;
//  
//  ASStackLayoutSpec *debugHelpStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  debugHelpStack.children = @[_debugSectionTitle, _vizNodeInsetSizeBtn, _vizNodeBordersBtn];
//  debugHelpStack.spacing = 5;
//  debugHelpStack.flexGrow = YES;
//
//  ASStackLayoutSpec *verticalLayoutableStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  verticalLayoutableStack.flexGrow = YES;
//  verticalLayoutableStack.spacing = 20;
//  verticalLayoutableStack.children = @[_parentNodeNavBtn, horizontalStackNav, _childNodeNavBtn, itemDescriptionStack, layoutableStack, layoutSpecStack, debugHelpStack];
//  verticalLayoutableStack.alignItems = ASStackLayoutAlignItemsStretch;                // stretch headerStack to fill horizontal space
//
//  ASLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(100, 10, 10, 10) child:verticalLayoutableStack];
//  insetSpec.flexGrow = YES;
//  return insetSpec;
//}
//
//#pragma mark - configure Inspector node for layoutable
//- (void)updateInspectorWithLayoutable
//{
//  _itemDescription.attributedString = [self attributedStringFromLayoutable:_layoutableToEdit];
//
//  if ([self node]) {
//    UIColor *nodeBackgroundColor = [[self node] backgroundColor];
//    UIImage *colorBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:nodeBackgroundColor
//                                                                            borderColor:[UIColor whiteColor]
//                                                                            borderWidth:3];
//    [_itemBackgroundColorBtn setBackgroundImage:colorBtnImg forState:ASControlStateNormal];
//  } else {
//    _itemBackgroundColorBtn.enabled = NO;
//  }
//  
//  _flexGrowBtn.selected           = [self.layoutableToEdit flexGrow];
//  _flexGrowValue.attributedString = [self attributedStringFromString: (_flexGrowBtn.selected) ? @"YES" : @"NO"];
//  
//  _flexShrinkBtn.selected           = self.layoutableToEdit.flexShrink;
//  _flexShrinkValue.attributedString = [self attributedStringFromString: (_flexShrinkBtn.selected) ? @"YES" : @"NO"];
//  
//  //  _flexBasisBtn.selected           = self.layoutableToEdit.flexShrink;
//  //  _flexBasisValue.attributedString = [self attributedStringFromString: (_flexBasisBtn.selected) ? @"YES" : @"NO"];
//  
//  
//  NSUInteger alignSelfValue = [self.layoutableToEdit alignSelf];
//  NSString *newTitle = [@"alignSelf:" stringByAppendingString:[self alignSelfName:alignSelfValue]];
//  [_alignSelfBtn setAttributedTitle:[self attributedStringFromString:newTitle] forState:ASControlStateNormal];
//  
//  if ([self layoutSpec]) {
//    _alignItemsBtn.enabled = YES;
////    NSUInteger alignItemsValue = [[self layoutSpec] alignItems];
////    newTitle = [@"alignItems:" stringByAppendingString:[self alignSelfName:alignItemsValue]];
////    [_alignItemsBtn setAttributedTitle:[self attributedStringFromString:newTitle] forState:ASControlStateNormal];
//  }
//
//  [self setNeedsLayout];
//}


//- (void)enableInspectorNodesForLayoutable
//{
//  if ([self layoutSpec]) {
//  
//    _itemBackgroundColorBtn.enabled = YES;
//    _flexGrowBtn.enabled        = YES;
//    _flexShrinkBtn.enabled      = YES;
//    _flexBasisBtn.enabled       = YES;
//    _alignSelfBtn.enabled       = YES;
//    _spacingBeforeBtn.enabled   = YES;
//    _spacingAfterBtn.enabled    = YES;
//    _alignItemsBtn.enabled      = YES;
//    
//  } else if ([self node]) {
//    
//    _itemBackgroundColorBtn.enabled = YES;
//    _flexGrowBtn.enabled        = YES;
//    _flexShrinkBtn.enabled      = YES;
//    _flexBasisBtn.enabled       = YES;
//    _alignSelfBtn.enabled       = YES;
//    _spacingBeforeBtn.enabled   = YES;
//    _spacingAfterBtn.enabled    = YES;
//    _alignItemsBtn.enabled      = NO;
//  
//  } else {
//    
//    _itemBackgroundColorBtn.enabled = NO;
//    _flexGrowBtn.enabled        = NO;
//    _flexShrinkBtn.enabled      = NO;
//    _flexBasisBtn.enabled       = NO;
//    _alignSelfBtn.enabled       = NO;
//    _spacingBeforeBtn.enabled   = NO;
//    _spacingAfterBtn.enabled    = NO;
//    _alignItemsBtn.enabled      = YES;
//  }
//}

//+ (NSDictionary *)alignSelfTypeNames
//{
//  return @{@(ASStackLayoutAlignSelfAuto) : @"Auto",
//           @(ASStackLayoutAlignSelfStart) : @"Start",
//           @(ASStackLayoutAlignSelfEnd) : @"End",
//           @(ASStackLayoutAlignSelfCenter) : @"Center",
//           @(ASStackLayoutAlignSelfStretch) : @"Stretch"};
//}
//
//- (NSString *)alignSelfName:(NSUInteger)type
//{
//  return [[self class] alignSelfTypeNames][@(type)];
//}
//
//+ (NSDictionary *)alignItemTypeNames
//{
//  return @{@(ASStackLayoutAlignItemsBaselineFirst) : @"BaselineFirst",
//           @(ASStackLayoutAlignItemsBaselineLast) : @"BaselineLast",
//           @(ASStackLayoutAlignItemsCenter) : @"Center",
//           @(ASStackLayoutAlignItemsEnd) : @"End",
//           @(ASStackLayoutAlignItemsStart) : @"Start",
//           @(ASStackLayoutAlignItemsStretch) : @"Stretch"};
//}
//
//- (NSString *)alignItemName:(NSUInteger)type
//{
//  return [[self class] alignItemTypeNames][@(type)];
//}

//#pragma mark - gesture handling
//- (void)changeColor:(ASButtonNode *)sender
//{
//  if ([self node]) {
//    NSArray *colorArray = @[[UIColor orangeColor],
//                            [UIColor redColor],
//                            [UIColor greenColor],
//                            [UIColor purpleColor]];
//    
//    UIColor *nodeBackgroundColor = [(ASDisplayNode *)self.layoutableToEdit backgroundColor];
//    
//    NSUInteger colorIndex = [colorArray indexOfObject:nodeBackgroundColor];
//    colorIndex = (colorIndex + 1 < [colorArray count]) ? colorIndex + 1 : 0;
//    
//    [[self node] setBackgroundColor: [colorArray objectAtIndex:colorIndex]];
//  }
//  
//  [self updateInspectorWithLayoutable];
//}
//
//- (void)setFlexGrowValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//  
//  if ([self layoutSpec]) {
//    [[self layoutSpec] setFlexGrow:sender.isSelected];
//  } else if ([self node]) {
//    [[self node] setFlexGrow:sender.isSelected];
//  }
//  
//  [self updateInspectorWithLayoutable];
//}
//
//- (void)setFlexShrinkValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//  
//  if ([self layoutSpec]) {
//    [[self layoutSpec] setFlexShrink:sender.isSelected];
//  } else if ([self node]) {
//    [[self node] setFlexShrink:sender.isSelected];
//  }
//  
//  [self updateInspectorWithLayoutable];
//}
//
//- (void)setAlignSelfValue:(ASButtonNode *)sender
//{
//  NSUInteger currentAlignSelfValue;
//  NSUInteger nextAlignSelfValue;
//  
//  if ([self layoutSpec]) {
//    currentAlignSelfValue = [[self layoutSpec] alignSelf];
//    nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
//    [[self layoutSpec] setAlignSelf:nextAlignSelfValue];
//    
//  } else if ([self node]) {
//    currentAlignSelfValue = [[self node] alignSelf];
//    nextAlignSelfValue = (currentAlignSelfValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignSelfValue + 1 : 0;
//    [[self node] setAlignSelf:nextAlignSelfValue];
//  }
//  
//  [self updateInspectorWithLayoutable];
//}
//
//- (void)setAlignItemsValue:(ASButtonNode *)sender
//{
//  NSUInteger currentAlignItemsValue;
//  NSUInteger nextAlignItemsValue;
//  
//  if ([self layoutSpec]) {
//    currentAlignItemsValue = [[self layoutSpec] alignSelf];
//    nextAlignItemsValue = (currentAlignItemsValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignItemsValue + 1 : 0;
////    [[self layoutSpec] setAlignItems:nextAlignItemsValue];
//    
//  } else if ([self node]) {
//    currentAlignItemsValue = [[self node] alignSelf];
//    nextAlignItemsValue = (currentAlignItemsValue + 1 <= ASStackLayoutAlignSelfStretch) ? currentAlignItemsValue + 1 : 0;
////    [[self node] setAlignItems:nextAlignItemsValue];
//  }
//  
//  [self updateInspectorWithLayoutable];
//}
//
//- (void)setVizNodeInsets:(ASButtonNode *)sender
//{
//  BOOL newState = !sender.selected;
//  
//  if (newState == YES) {
//    self.vizNodeInsetSize = 0;
//    [self.delegate toggleVizualization:NO];   // FIXME
//    [self.delegate toggleVizualization:YES];   // FIXME
//    _vizNodeBordersBtn.selected = YES;
//    
//  } else {
//    self.vizNodeInsetSize = 10;
//    [self.delegate toggleVizualization:NO];   // FIXME
//    [self.delegate toggleVizualization:YES];   // FIXME
//  }
//  
//  sender.selected = newState;
//}
//
//- (void)setVizNodeBorders:(ASButtonNode *)sender
//{
//  BOOL newState = !sender.selected;
//  
//  [self.delegate toggleVizualization:newState];   // FIXME
//
//  sender.selected = newState;
//}



//
//- (void)setFlexBasisValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//
//  // FIXME: finish
//}

#pragma mark - cast layoutableToEdit

//- (ASDisplayNode *)node                                                         // FIXME: move to ASLayoutSpec? or make a category?
//{
//  if ([self.layoutableToEdit isKindOfClass:[ASDisplayNode class]]) {
//    return (ASDisplayNode *)self.layoutableToEdit;
//  }
//  return nil;
//}
//
//- (ASLayoutSpec *)layoutSpec
//{
//  if ([self.layoutableToEdit isKindOfClass:[ASLayoutSpec class]]) {
//    return (ASLayoutSpec *)self.layoutableToEdit;
//  }
//  return nil;
//}

#pragma mark - helper methods

//- (NSAttributedString *)attributedStringFromLayoutable:(id<ASLayoutable>)layoutable   // FIXME: move to Utilities.h
//{
//  if ([self layoutSpec]) {
//    return [self attributedStringFromString:[[self layoutSpec] description]];
//  } else if ([self node]) {
//    return [self attributedStringFromString:[[self node] description]];
//  }
//  return nil;
//}
//
//- (NSAttributedString *)attributedStringFromString:(NSString *)string
//{
//  return [self attributedStringFromString:string withTextColor:[UIColor whiteColor]];
//}
//
//- (NSAttributedString *)attributedStringFromString:(NSString *)string withTextColor:(nullable UIColor *)color
//{
//  NSDictionary *attributes = @{NSForegroundColorAttributeName : color,
//                               NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular" size:12]};
//  
//  return [[NSAttributedString alloc] initWithString:string attributes:attributes];
//}
//
//- (ASButtonNode *)makeBtnNodeWithTitle:(NSString *)title
//{
//  UIColor *orangeColor = [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1];
//  UIImage *orangeStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:orangeColor
//                                                                                  borderColor:[UIColor whiteColor]
//                                                                                  borderWidth:3];
//  UIImage *greyStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:[UIColor darkGrayColor]
//                                                                                borderColor:[UIColor lightGrayColor]
//                                                                                borderWidth:3];
//  UIImage *clearStretchBtnImg = [ASLayoutableInspectorNode imageForButtonWithBackgroundColor:[UIColor clearColor]
//                                                                                 borderColor:[UIColor whiteColor]
//                                                                                 borderWidth:3];
//  ASButtonNode *btn = [[ASButtonNode alloc] init];
//  btn.contentEdgeInsets = UIEdgeInsetsMake(5, 5, 5, 5);
//  [btn setAttributedTitle:[self attributedStringFromString:title] forState:ASControlStateNormal];
//  [btn setAttributedTitle:[self attributedStringFromString:title withTextColor:[UIColor lightGrayColor]] forState:ASControlStateDisabled];
//  [btn setBackgroundImage:clearStretchBtnImg forState:ASControlStateNormal];
//  [btn setBackgroundImage:orangeStretchBtnImg forState:ASControlStateSelected];
//  [btn setBackgroundImage:greyStretchBtnImg forState:ASControlStateDisabled];
//  
//  return btn;
//}
//
//#define CORNER_RADIUS 3
//+ (UIImage *)imageForButtonWithBackgroundColor:(UIColor *)backgroundColor borderColor:(UIColor *)borderColor borderWidth:(CGFloat)width
//{
//  CGSize unstretchedSize  = CGSizeMake(2 * CORNER_RADIUS + 1, 2 * CORNER_RADIUS + 1);
//  CGRect rect             = (CGRect) {CGPointZero, unstretchedSize};
//  UIBezierPath *path      = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:CORNER_RADIUS];
//  
//  // create a graphics context for the following status button
//  UIGraphicsBeginImageContextWithOptions(unstretchedSize, NO, 0);
//  
//  [path addClip];
//  [backgroundColor setFill];
//  [path fill];
//  
//  path.lineWidth = width;
//  [borderColor setStroke];
//  [path stroke];
//  
//  UIImage *btnImage = UIGraphicsGetImageFromCurrentImageContext();
//  UIGraphicsEndImageContext();
//  
//  return [btnImage stretchableImageWithLeftCapWidth:CORNER_RADIUS topCapHeight:CORNER_RADIUS];
//}



@end
