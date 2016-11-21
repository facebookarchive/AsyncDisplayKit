//
//  ASLayoutElementInspectorNode.m
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASLayoutElementInspectorNode.h"
#import "ASLayoutElementInspectorCell.h"
#import "ASDisplayNode+Beta.h"
#import "ASLayoutSpec+Debug.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASLayoutElementInspectorNode () <ASTableDelegate, ASTableDataSource>
@end

@implementation ASLayoutElementInspectorNode
{
  ASTableNode  *_tableNode;
}

#pragma mark - class methods
+ (instancetype)sharedInstance
{
  static ASLayoutElementInspectorNode *__inspector = nil;
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    __inspector = [[ASLayoutElementInspectorNode alloc] init];
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
  _tableNode.view.sectionHeaderHeight = 40;
}

- (void)layout
{
  [super layout];
  _tableNode.frame = self.bounds;
}

#pragma mark - intstance methods
- (void)setLayoutElementToEdit:(id<ASLayoutElement>)layoutElementToEdit
{
  if (_layoutElementToEdit != layoutElementToEdit) {
    _layoutElementToEdit = layoutElementToEdit;
  }
  [_tableNode reloadData];
}

#pragma mark - ASTableDataSource

- (ASCellNode *)tableView:(ASTableView *)tableView nodeForRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.section == 0) {
    NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor colorWithRed:255/255.0 green:181/255.0 blue:68/255.0 alpha:1],
                                 NSFontAttributeName : [UIFont fontWithName:@"Menlo-Regular" size:12]};
    ASTextCellNode *textCell = [[ASTextCellNode alloc] initWithAttributes:attributes insets:UIEdgeInsetsMake(0, 4, 0, 0)];
    textCell.text = [_layoutElementToEdit description];
    return textCell;
  } else {
    return [[ASLayoutElementInspectorCell alloc] initWithProperty:(ASLayoutElementPropertyType)indexPath.row layoutElementToEdit:_layoutElementToEdit];
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    return 1;
  } else {
    return ASLayoutElementPropertyCount;
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
  UILabel *headerTitle = [[UILabel alloc] initWithFrame:CGRectZero];
  
  NSString *title;
  if (section == 0) {
    title = @"<Layoutable> Item";
  } else {
    title = @"<Layoutable> Properties";
  }
  
  NSDictionary *attributes = @{NSForegroundColorAttributeName : [UIColor whiteColor],
                               NSFontAttributeName : [UIFont fontWithName:@"Menlo-Bold" size:12]};
  headerTitle.attributedText = [[NSAttributedString alloc] initWithString:title attributes:attributes];
  
  return headerTitle;
}

//- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
//{
//  // navigate layout hierarchy
//  
//  _parentNodeNavBtn.alignSelf = ASStackLayoutAlignSelfCenter;
//  _childNodeNavBtn.alignSelf = ASStackLayoutAlignSelfCenter;
//
//  ASStackLayoutSpec *horizontalStackNav = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStackNav.style.flexGrow = 1.0;
//  horizontalStackNav.alignSelf = ASStackLayoutAlignSelfCenter;
//  horizontalStackNav.children = @[_siblingNodeLefttNavBtn, _siblingNodeRightNavBtn];
//  
//  ASStackLayoutSpec *horizontalStack = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack.style.flexGrow = 1.0;
//  ASLayoutSpec *spacer = [[ASLayoutSpec alloc] init];
//  
//  spacer.style.flexGrow = 1.0;
//  horizontalStack.children = @[_flexGrowBtn, spacer];
//  _flexGrowValue.alignSelf = ASStackLayoutAlignSelfEnd;      // FIXME: make framework give a warning if you use ASAlignmentBottom!!!!!
//  
//  ASStackLayoutSpec *horizontalStack2 = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack2.style.flexGrow = 1.0;
//  horizontalStack2.children = @[_flexShrinkBtn, spacer];
//  _flexShrinkValue.alignSelf = ASStackLayoutAlignSelfEnd;
//  
//  ASStackLayoutSpec *horizontalStack3 = [ASStackLayoutSpec horizontalStackLayoutSpec];
//  horizontalStack3.style.flexGrow = 1.0;
//  horizontalStack3.children = @[_flexBasisBtn, spacer, _flexBasisValue];
//  _flexBasisValue.alignSelf = ASStackLayoutAlignSelfEnd;
//  
//  ASStackLayoutSpec *itemDescriptionStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  itemDescriptionStack.children = @[_itemDescription];
//  itemDescriptionStack.spacing = 5;
//  itemDescriptionStack.style.flexGrow = 1.0;
//  
//  ASStackLayoutSpec *layoutableStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  layoutableStack.children = @[_layoutablePropertiesSectionTitle, horizontalStack, horizontalStack2, horizontalStack3, _alignSelfBtn];
//  layoutableStack.spacing = 5;
//  layoutableStack.style.flexGrow = 1.0;
//  
//  ASStackLayoutSpec *layoutSpecStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  layoutSpecStack.children = @[_layoutSpecPropertiesSectionTitle, _alignItemsBtn];
//  layoutSpecStack.spacing = 5;
//  layoutSpecStack.style.flexGrow = 1.0;
//  
//  ASStackLayoutSpec *debugHelpStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  debugHelpStack.children = @[_debugSectionTitle, _vizNodeInsetSizeBtn, _vizNodeBordersBtn];
//  debugHelpStack.spacing = 5;
//  debugHelpStack.style.flexGrow = 1.0;
//
//  ASStackLayoutSpec *verticalLayoutableStack = [ASStackLayoutSpec verticalStackLayoutSpec];
//  verticalLayoutableStack.style.flexGrow = 1.0;
//  verticalLayoutableStack.spacing = 20;
//  verticalLayoutableStack.children = @[_parentNodeNavBtn, horizontalStackNav, _childNodeNavBtn, itemDescriptionStack, layoutableStack, layoutSpecStack, debugHelpStack];
//  verticalLayoutableStack.alignItems = ASStackLayoutAlignItemsStretch;                // stretch headerStack to fill horizontal space
//
//  ASLayoutSpec *insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(100, 10, 10, 10) child:verticalLayoutableStack];
//  insetSpec.style.flexGrow = 1.0;
//  return insetSpec;
//}
//
//#pragma mark - configure Inspector node for layoutable
//- (void)updateInspectorWithLayoutable
//{
//  _itemDescription.attributedText = [self attributedStringFromLayoutable:_layoutElementToEdit];
//
//  if ([self node]) {
//    UIColor *nodeBackgroundColor = [[self node] backgroundColor];
//    UIImage *colorBtnImg = [ASLayoutElementInspectorNode imageForButtonWithBackgroundColor:nodeBackgroundColor
//                                                                            borderColor:[UIColor whiteColor]
//                                                                            borderWidth:3];
//    [_itemBackgroundColorBtn setBackgroundImage:colorBtnImg forState:ASControlStateNormal];
//  } else {
//    _itemBackgroundColorBtn.enabled = NO;
//  }
//  
//  _flexGrowBtn.selected           = [self.layoutElementToEdit flexGrow];
//  _flexGrowValue.attributedText = [self attributedStringFromString: (_flexGrowBtn.selected) ? @"YES" : @"NO"];
//  
//  _flexShrinkBtn.selected           = self.layoutElementToEdit.style.flexShrink;
//  _flexShrinkValue.attributedText = [self attributedStringFromString: (_flexShrinkBtn.selected) ? @"YES" : @"NO"];
//  
//  //  _flexBasisBtn.selected           = self.layoutElementToEdit.style.flexShrink;
//  //  _flexBasisValue.attributedText = [self attributedStringFromString: (_flexBasisBtn.selected) ? @"YES" : @"NO"];
//  
//  
//  NSUInteger alignSelfValue = [self.layoutElementToEdit alignSelf];
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
//    UIColor *nodeBackgroundColor = [(ASDisplayNode *)self.layoutElementToEdit backgroundColor];
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
//- (void)setFlexBasisValue:(ASButtonNode *)sender
//{
//  [sender setSelected:!sender.isSelected];   // FIXME: fix ASControlNode documentation that this is automatic - unlike highlighted, it is up to the application to decide when a button should be selected or not. Selected is a more persistant thing and highlighted is for the moment, like as a user has a finger on it,
//   FIXME: finish
//}
//
//- (void)setVizNodeInsets:(ASButtonNode *)sender
//{
//  BOOL newState = !sender.selected;
//  
//  if (newState == YES) {
//    self.vizNodeInsetSize = 0;
//    [self.delegate toggleVisualization:NO];   // FIXME
//    [self.delegate toggleVisualization:YES];   // FIXME
//    _vizNodeBordersBtn.selected = YES;
//    
//  } else {
//    self.vizNodeInsetSize = 10;
//    [self.delegate toggleVisualization:NO];   // FIXME
//    [self.delegate toggleVisualization:YES];   // FIXME
//  }
//  
//  sender.selected = newState;
//}
//
//- (void)setVizNodeBorders:(ASButtonNode *)sender
//{
//  BOOL newState = !sender.selected;
//  
//  [self.delegate toggleVisualization:newState];   // FIXME
//
//  sender.selected = newState;
//}

@end
