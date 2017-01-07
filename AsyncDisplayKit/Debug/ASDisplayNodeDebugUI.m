//
//  ASDisplayNodeDebugUI.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDisplayNodeDebugUI.h"
#import "ASDisplayNodeDebugViewController.h"

@interface ASDisplayNodeDebugUIManager ()
@property (nonatomic, strong) UIWindow *window;
// Weak because window will own view controller.
@property (nonatomic, weak) ASDisplayNodeDebugViewController *viewController;
@end

@implementation ASDisplayNodeDebugUIManager

+ (ASDisplayNodeDebugUIManager *)sharedManager
{
  static ASDisplayNodeDebugUIManager *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[ASDisplayNodeDebugUIManager alloc] init];
  });
  return instance;
}

- (void)showDebugUIWithNode:(ASDisplayNode *)node sizes:(nullable NSArray<NSValue *> *)sizes
{
  // If we're already showing, just ignore the call. We could assert but this is debugging, keep it simple.
  if (self.window && !self.window.hidden) {
    return;
  }
  
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  self.window.windowLevel = UIWindowLevelStatusBar + 1;
  
  ASDisplayNodeDebugViewController *vc = [[ASDisplayNodeDebugViewController alloc] initWithNodeForDebugging:node sizes:sizes];
  self.window.rootViewController = vc;
  [self.window makeKeyAndVisible];
}

- (void)dismissDebugUI
{
  self.window.hidden = nil;
}

@end
