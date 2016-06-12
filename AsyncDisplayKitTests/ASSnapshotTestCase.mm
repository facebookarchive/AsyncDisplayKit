//
//  ASSnapshotTestCase.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASSnapshotTestCase.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNodeInternal.h"

@implementation ASSnapshotTestCase

+ (void)_layoutAndDisplayNode:(ASDisplayNode *)node
{
  if (![node __shouldLoadViewOrLayer]) {
    return;
  }

  CALayer *layer = node.layer;

  [layer setNeedsLayout];
  [layer layoutIfNeeded];

  [layer setNeedsDisplay];
  [layer displayIfNeeded];
}

+ (void)_recursivelyLayoutAndDisplayNode:(ASDisplayNode *)node
{
  for (ASDisplayNode *subnode in node.subnodes) {
    [self _recursivelyLayoutAndDisplayNode:subnode];
  }

  [self _layoutAndDisplayNode:node];
}

+ (void)_recursivelySetDisplaysAsynchronously:(BOOL)flag forNode:(ASDisplayNode *)node
{
  node.displaysAsynchronously = flag;

  for (ASDisplayNode *subnode in node.subnodes) {
    subnode.displaysAsynchronously = flag;
  }
}

+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node
{
// TODO: Reconfigure this to be able to use [node recursivelyEnsureDisplay];
  [self _recursivelySetDisplaysAsynchronously:NO forNode:node];
  [self _recursivelyLayoutAndDisplayNode:node];
}

@end
