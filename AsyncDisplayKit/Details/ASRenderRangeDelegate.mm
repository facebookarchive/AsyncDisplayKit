/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASRenderRangeDelegate.h"

#import "ASDisplayNode.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeInternal.h"

@interface ASDisplayNode (ASRenderRangeDelegate)

- (void)display;
- (void)recursivelyDisplay;

@end

@implementation ASDisplayNode (ASRenderRangeDelegate)

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

@implementation ASRenderRangeDelegate

- (void)node:(ASDisplayNode *)node enteredRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  // if node is in the working range it should not actively be in view
  [node.view removeFromSuperview];

  [node recursivelyDisplay];
}

- (void)node:(ASDisplayNode *)node exitedRangeType:(ASLayoutRangeType)rangeType
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(node, @"invalid argument");

  [node recursivelySetDisplaySuspended:YES];
  [node.view removeFromSuperview];

  // since this class usually manages large or infinite data sets, the working range
  // directly bounds memory usage by requiring redrawing any content that falls outside the range.
  [node recursivelyClearRendering];
}

@end
