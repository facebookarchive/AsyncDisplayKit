//
//  ASTipsWindow.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTipsWindow.h"
#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASDisplayNodeTipState.h>
#import <AsyncDisplayKit/ASTipNode.h>
#import <AsyncDisplayKit/ASTip.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Tips.h>

@interface ASTipsWindow ()
@property (nonatomic, strong, readonly) ASDisplayNode *node;
@end

@implementation ASTipsWindow

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    /**
     * UIKit throws an exception if you don't add a root view controller to a window,
     * but if the window isn't key, then it doesn't manage the root view controller correctly!
     *
     * So we set a dummy root view controller and hide it.
     */
    self.rootViewController = [UIViewController new];
    self.rootViewController.view.hidden = YES;

    _node = [[ASDisplayNode alloc] init];
    [self addSubnode:_node];

    self.windowLevel = UIWindowLevelNormal + 1;
    self.opaque = NO;
  }
  return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *result = [super hitTest:point withEvent:event];
  // Ignore touches unless they hit one of my node's subnodes
  if (result == _node.view) {
    return nil;
  }
  return result;
}

- (void)setMainWindow:(UIWindow *)mainWindow
{
  _mainWindow = mainWindow;
  for (ASDisplayNode *node in _node.subnodes) {
    [node removeFromSupernode];
  }
}

- (void)didTapTipNode:(ASTipNode *)tipNode
{
  ASDisplayNode.tipDisplayBlock(tipNode.tip.node, tipNode.tip.text);
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _node.frame = self.bounds;
  
  // Ensure the main window is laid out first.
  [self.mainWindow layoutIfNeeded];
  
  NSMutableSet *tipNodesToRemove = [NSMutableSet setWithArray:_node.subnodes];
  for (ASDisplayNodeTipState *tipState in [_nodeToTipStates objectEnumerator]) {
    ASDisplayNode *node = tipState.node;
    ASTipNode *tipNode = tipState.tipNode;
    [tipNodesToRemove removeObject:tipNode];
    CGRect rect = node.bounds;
    rect = [node.view convertRect:rect toView:nil];
    rect = [self convertRect:rect fromView:nil];
    tipNode.frame = rect;
    if (tipNode.supernode != _node) {
      [_node addSubnode:tipNode];
    }
  }
  
  // Clean up any tip nodes whose target nodes have disappeared.
  for (ASTipNode *tipNode in tipNodesToRemove) {
    [tipNode removeFromSupernode];
  }
}

@end

#endif // AS_ENABLE_TIPS
