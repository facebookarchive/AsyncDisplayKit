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

@interface ASDisplayNode (ASRangeHandlerRender)

- (void)display;
- (void)recursivelyDisplay;

@end

@implementation ASDisplayNode (ASRangeHandlerRender)

- (void)display
{
  if (![self __shouldLoadViewOrLayer]) {
    return;
  }

  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"backing store must be loaded before calling -display");

  CALayer *layer = self.layer;

  // rendering a backing store requires a node be laid out
  [layer setNeedsLayout];
  [layer layoutIfNeeded];

  if (layer.contents) {
    return;
  }

  [layer setNeedsDisplay];
  [layer displayIfNeeded];
}

- (void)recursivelyDisplay
{
  if (![self __shouldLoadViewOrLayer]) {
    return;
  }

  for (ASDisplayNode *node in self.subnodes) {
    [node recursivelyDisplay];
  }

  [self display];
}

@end

@implementation ASRangeHandlerRender

- (void)node:(ASDisplayNode *)node enteredRangeOfType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(rangeType == ASLayoutRangeTypeRender, @"Render delegate should not handle other ranges");

  // if node is in the working range it should not actively be in view
  [node.view removeFromSuperview];

  [node recursivelyDisplay];
}

- (void)node:(ASDisplayNode *)node exitedRangeOfType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(rangeType == ASLayoutRangeTypeRender, @"Render delegate should not handle other ranges");

  [node recursivelySetDisplaySuspended:YES];
  [node.view removeFromSuperview];

  [node recursivelyClearRendering];
}

@end
