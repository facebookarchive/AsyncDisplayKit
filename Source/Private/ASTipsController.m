//
//  ASTipsController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTipsController.h"

#if AS_ENABLE_TIPS

#import <AsyncDisplayKit/ASDisplayNodeTipState.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Tips.h>
#import <AsyncDisplayKit/ASTipNode.h>
#import <AsyncDisplayKit/ASTipProvider.h>
#import <AsyncDisplayKit/ASTipsWindow.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>

@interface ASTipsController ()

/// Nil on init, updates to most recent visible window.
@property (nonatomic, strong) UIWindow *appVisibleWindow;

/// Nil until an application window has become visible.
@property (nonatomic, strong) ASTipsWindow *tipWindow;

/// Main-thread-only.
@property (nonatomic, strong, readonly) NSMapTable<ASDisplayNode *, ASDisplayNodeTipState *> *nodeToTipStates;

@property (nonatomic, strong) NSMutableArray<ASDisplayNode *> *nodesThatAppearedDuringRunLoop;

@end

@implementation ASTipsController

#pragma mark - Singleton

+ (void)load
{
  [NSNotificationCenter.defaultCenter addObserver:self.shared
                                         selector:@selector(windowDidBecomeVisibleWithNotification:)
                                             name:UIWindowDidBecomeVisibleNotification
                                           object:nil];
}

+ (ASTipsController *)shared
{
  static ASTipsController *ctrl;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ctrl = [[ASTipsController alloc] init];
  });
  return ctrl;
}

#pragma mark - Lifecycle

- (instancetype)init
{
  ASDisplayNodeAssertMainThread();
  if (self = [super init]) {
    _nodeToTipStates = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality) valueOptions:NSPointerFunctionsStrongMemory];
    _nodesThatAppearedDuringRunLoop = [NSMutableArray array];
  }
  return self;
}

#pragma mark - Event Handling

- (void)nodeDidAppear:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();
  // If they disabled tips on this class, bail.
  if (![[node class] enableTips]) {
    return;
  }

  // If this node appeared in some other window (like our tips window) ignore it.
  if (ASFindWindowOfLayer(node.layer) != self.appVisibleWindow) {
    return;
  }

  [_nodesThatAppearedDuringRunLoop addObject:node];
}

// If this is a main window, start watching it and clear out our tip window.
- (void)windowDidBecomeVisibleWithNotification:(NSNotification *)notification
{
  ASDisplayNodeAssertMainThread();
  UIWindow *window = notification.object;

  // If this is the same window we're already watching, bail.
  if (window == self.appVisibleWindow) {
    return;
  }

  // Ignore windows that are not at the normal level or have empty bounds
  if (window.windowLevel != UIWindowLevelNormal || CGRectIsEmpty(window.bounds)) {
    return;
  }

  self.appVisibleWindow = window;

  // Create the tip window if needed.
  [self createTipWindowIfNeededWithFrame:window.bounds];

  // Clear out our tip window and reset our states.
  self.tipWindow.mainWindow = window;
  [_nodeToTipStates removeAllObjects];
}

- (void)runLoopDidTick
{
  NSArray *nodes = [_nodesThatAppearedDuringRunLoop copy];
  [_nodesThatAppearedDuringRunLoop removeAllObjects];

  // Go through the old array, removing any that have tips but aren't still visible.
  for (ASDisplayNode *node in [_nodeToTipStates copy]) {
    if (!node.visible) {
      [_nodeToTipStates removeObjectForKey:node];
    }
  }

  for (ASDisplayNode *node in nodes) {
    // Get the tip state for the node.
    ASDisplayNodeTipState *tipState = [_nodeToTipStates objectForKey:node];

    // If the node already has a tip, bail. This could change.
    if (tipState.tipNode != nil) {
      return;
    }

    for (ASTipProvider *provider in ASTipProvider.all) {
      ASTip *tip = [provider tipForNode:node];
      if (!tip) { continue; }

      if (!tipState) {
        tipState = [self createTipStateForNode:node];
      }
      tipState.tipNode = [[ASTipNode alloc] initWithTip:tip];
    }
  }
  self.tipWindow.nodeToTipStates = _nodeToTipStates;
  [self.tipWindow setNeedsLayout];
}

#pragma mark - Internal

- (void)createTipWindowIfNeededWithFrame:(CGRect)tipWindowFrame
{
  // Lots of property accesses, but simple safe code, only run once.
  if (self.tipWindow == nil) {
    self.tipWindow = [[ASTipsWindow alloc] initWithFrame:tipWindowFrame];
    self.tipWindow.hidden = NO;
    [self setupRunLoopObserver];
  }
}

/**
 * In order to keep the UI updated, the tips controller registers a run loop observer.
 * Before the transaction commit happens, the tips controller calls -setNeedsLayout
 * on the view controller's view. It will then layout the main window, and then update the frames
 * for tip nodes accordingly.
 */
- (void)setupRunLoopObserver
{
  CFRunLoopObserverRef o = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
    [self runLoopDidTick];
  });
  CFRunLoopAddObserver(CFRunLoopGetMain(), o, kCFRunLoopCommonModes);
}

- (ASDisplayNodeTipState *)createTipStateForNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeTipState *tipState = [[ASDisplayNodeTipState alloc] initWithNode:node];
  [_nodeToTipStates setObject:tipState forKey:node];
  return tipState;
}

@end

#endif // AS_ENABLE_TIPS
