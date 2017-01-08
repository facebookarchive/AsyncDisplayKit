//
//  ASDisplayNodeDebugViewController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDisplayNodeDebugViewController.h"
#import "ASLayoutSpecDebuggingContext.h"
#import "ASDebugOverlayRootViewController.h"

@interface ASDisplayNodeDebugViewController () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) ASButtonNode *button;

// A node we put around the user's node.
@property (nonatomic, strong) ASDisplayNode *debuggingContainerNode;

// The node the user is testing.
@property (nonatomic, strong) ASDisplayNode *debuggingNode;

@property (nonatomic, strong, nullable) NSValue *selectedSize;
@property (nonatomic, strong) NSArray<NSValue *> *sizes;
@property (nonatomic, strong) UIPanGestureRecognizer *panRecognizer;
@property (nonatomic) UIRectEdge panRectEdge;
@property (nonatomic, strong) ASLayoutSpecTree *tree;
@end

@implementation ASDisplayNodeDebugViewController

- (instancetype)initWithNodeForDebugging:(ASDisplayNode *)debuggingNode sizes:(NSArray<NSValue *> *)sizes
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.backgroundColor = [UIColor blackColor];
  if (self = [super initWithNode:node]) {
    _debuggingNode = debuggingNode;
    _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
    _panRecognizer.delegate = self;
    // If they specify no sizes, use the size of the main screen.
    if (sizes.count == 0) {
      sizes = @[ [NSValue valueWithCGSize:[UIScreen mainScreen].bounds.size] ];
    }
    _sizes = [sizes copy];
    _selectedSize = sizes.firstObject;
    
    // Setup debugging container node.
    ASDisplayNode *debuggingContainerNode = [[ASDisplayNode alloc] init];
    debuggingContainerNode.backgroundColor = [[UIColor purpleColor] colorWithAlphaComponent:0.6];
    debuggingContainerNode.layoutSpecBlock = ^(ASDisplayNode *debuggingContainerNode, ASSizeRange constrainedSize) {
      return [ASWrapperLayoutSpec wrapperWithLayoutElement:debuggingNode];
    };
    debuggingContainerNode.style.preferredSize = [_selectedSize CGSizeValue];
    [debuggingContainerNode addSubnode:debuggingNode];
    _debuggingContainerNode = debuggingContainerNode;
    [node addSubnode:debuggingContainerNode];
    
    // Setup button
    ASButtonNode *btn = [[ASButtonNode alloc] init];
    [btn setTitle:@"Info" withFont:[UIFont boldSystemFontOfSize:20] withColor:[UIColor blueColor] forState:ASControlStateNormal];
    [btn addTarget:self action:@selector(buttonAction) forControlEvents:ASControlNodeEventTouchUpInside];
    _button = btn;
    [node addSubnode:btn];
    
    // Setup layout
    node.layoutSpecBlock = ^(ASDisplayNode *node, ASSizeRange constrainedSize) {
      ASCenterLayoutSpec *centerSpec = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionMinimumXY child:debuggingContainerNode];
      ASStackLayoutSpec *btnStack = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical spacing:0 justifyContent:ASStackLayoutJustifyContentEnd alignItems:ASStackLayoutAlignItemsEnd children:@[ btn ]];
      return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:centerSpec overlay:btnStack];
    };
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  [self.view addGestureRecognizer:self.panRecognizer];
}

/**
 * This is different from selectedSize. selectedSize refers to the presets we were given in init.
 */
- (CGSize)currentSize
{
  return self.debuggingContainerNode.style.preferredSize;
}

- (void)buttonAction
{
  ASDebugOverlayRootViewController *vc = [[ASDebugOverlayRootViewController alloc] init];
  vc.tree = self.tree;
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
  [self presentViewController:nav animated:YES completion:nil];
}

/**
 * Handle our pan
 */
- (void)didPan:(UIPanGestureRecognizer *)panRecognizer
{
  UIView *view = self.debuggingContainerNode.view;
  CGPoint location = [panRecognizer locationInView:view];
  
  // If we just began, compute our rect edge.
  if (panRecognizer.state == UIGestureRecognizerStateBegan) {
    CGRect bounds = view.bounds;
    UIRectEdge newEdge = UIRectEdgeNone;
    if (location.x >= CGRectGetMidX(bounds)) {
      newEdge |= UIRectEdgeRight;
    } else {
      newEdge |= UIRectEdgeLeft;
    }
    if (location.y >= CGRectGetMidY(bounds)) {
      newEdge |= UIRectEdgeBottom;
    } else {
      newEdge |= UIRectEdgeTop;
    }
    _panRectEdge = newEdge;
  }
  
  if (panRecognizer.state == UIGestureRecognizerStateChanged) {
    // Otherwise update our size
    CGPoint translation = [panRecognizer translationInView:self.view];
    CGSize newSize = self.debuggingContainerNode.style.preferredSize;
    newSize.width += translation.x * 2 * (_panRectEdge & UIRectEdgeRight ? 1 : -1);
    newSize.height += translation.y * 2 * (_panRectEdge & UIRectEdgeBottom ? 1 : -1);
    if (ASIsCGSizeValidForSize(newSize)) {
      self.debuggingContainerNode.style.preferredSize = newSize;
    }
    [panRecognizer setTranslation:CGPointZero inView:self.view];
    [self.debuggingContainerNode invalidateCalculatedLayout];
    [self.node setNeedsLayout];
  }
}

- (void)viewWillLayoutSubviews
{
  [ASLayoutSpecTree beginWithElement:nil];
  [super viewWillLayoutSubviews];
}

- (void)viewDidLayoutSubviews
{
  ASLayoutSpecTree *treeForVC = [ASLayoutSpecTree currentTree];
  [ASLayoutSpecTree end];
  
  self.tree = [treeForVC subtreeForElement:self.debuggingNode];
  [super viewDidLayoutSubviews];
}

@end
