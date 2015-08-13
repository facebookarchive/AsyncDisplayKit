/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRangeHandlerRender.h"

#import "ASDisplayNode.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeInternal.h"

@implementation ASRangeHandlerRender

+ (UIWindow *)workingWindow
{
  ASDisplayNodeAssertMainThread();
  
  // we add nodes' views to this invisible window to start async rendering
  // TODO: Replace this with directly triggering display https://github.com/facebook/AsyncDisplayKit/issues/315
  static UIWindow *workingWindow = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    workingWindow = [[UIWindow alloc] initWithFrame:CGRectZero];
    workingWindow.windowLevel = UIWindowLevelNormal - 1000;
    workingWindow.userInteractionEnabled = NO;
    workingWindow.hidden = YES;
    workingWindow.alpha = 0.0;
  });
  return workingWindow;
}

- (void)node:(ASDisplayNode *)node enteredRangeOfType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(rangeType == ASLayoutRangeTypeRender, @"Render delegate should not handle other ranges");

  [node recursivelySetDisplaySuspended:NO];

  // Add the node's layer to an off-screen window to trigger display and mark its contents as non-volatile.
  // Use the layer directly to avoid the substantial overhead of UIView heirarchy manipulations.
  // Any view-backed nodes will still create their views in order to assemble the layer heirarchy, and they will
  // also assemble a view subtree for the node, but we avoid the much more significant expense triggered by a view
  // being added or removed from an onscreen window (responder chain setup, will/DidMoveToWindow: recursive calls, etc)
  [[[self.class workingWindow] layer] addSublayer:node.layer];
}

- (void)node:(ASDisplayNode *)node exitedRangeOfType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(rangeType == ASLayoutRangeTypeRender, @"Render delegate should not handle other ranges");

  [node recursivelySetDisplaySuspended:YES];
  [node.layer removeFromSuperlayer];

  [node recursivelyClearContents];
}

@end
