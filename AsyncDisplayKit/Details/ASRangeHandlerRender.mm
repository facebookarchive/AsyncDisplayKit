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
  [[[[self class] workingWindow] layer] addSublayer:node.layer];
}

- (void)node:(ASDisplayNode *)node exitedRangeOfType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(rangeType == ASLayoutRangeTypeRender, @"Render delegate should not handle other ranges");

  // This code is tricky.  There are several possible states a node can be in when it reaches this point.
  // 1. Layer-backed vs view-backed nodes.  AS of this writing, only ASCellNodes arrive here, which are always view-backed —
  //    but we maintain correctness for all ASDisplayNodes, including layer-backed ones.
  //    (Note: it would not make sense to pass in a subnode of a rasterized node here, so that is unsupported).
  // 2. The node's layer may have been added to the workingWindow previously, or it may have never been added, such as if rangeTuningParameter's leading value is 0.
  // 3. The node's layer may not be present in the workingWindow, even if it was previously added.
  //    This is a common case, as once the node is added to an active cell contentsView (e.g. visible), it is automatically removed from the workingWindow.
  //    The system does this when addSublayer is called, even if removeFromSuperlayer is never explicitly called.
  // 4. Lastly and most unusually, it is possible for a node to be offscreen, completely outside the heirarchy, and yet considered within the working range.
  //    This happens if the UITableViewCell is reused after scrolling offscreen.  Because the node has already been given the opportunity to display, we do not
  //    proactively re-host it within the workingWindow (improving efficiency).  Some time later, it may fall outside the working range, in which case calling
  //    -recursivelyClearContents is critical.  If the user scrolls back and it is re-hosted in a UITableViewCell, the content will still exist as it is not cleared
  //    by simply being removed from the cell.  The code that usually triggers this condition is the -removeFromSuperview in -[ASRangeController configureContentView:forCellNode:].
  // Condition #4 is suboptimal in some cases, as it is conceivable that memory warnings could trigger clearing content that is inside the working range.  However, enforcing the
  // preservation of this content could result in the app being killed, which is not likely preferable over briefly seeing placeholders in the event the user scrolls backwards.
  // Nonetheless, future changes to the implementation will likely eliminate this behavior to simplify debugging and extensibility of working range functionality.
  
  [node recursivelySetDisplaySuspended:YES];
  
  if (node.layer.superlayer != [[[self class] workingWindow] layer]) {
    // In this case, the node has previously passed through the working range (or it is zero), and it has now fallen outside the working range.
    if (![node isLayerBacked]) {
      // If the node is view-backed, we need to make sure to remove the view (which is now present in the containing cell contentsView).
      // Layer-backed nodes will be fully handled by the unconditional removal below.
      [node.view removeFromSuperview];
    }
  }
  
  // At this point, the node's layer may validly be present either in the workingWindow, or in the contentsView of a cell.
  [node.layer removeFromSuperlayer];
  [node recursivelyClearContents];
}

@end
