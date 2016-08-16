//
//  ASSnapshotTestCase.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASSnapshotTestCase.h"
#import "ASDisplayNode+Beta.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+Subclasses.h"

@implementation ASSnapshotTestCase

+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertNotNil(node.calculatedLayout, @"Node %@ must be measured before it is rendered.", node);
  node.bounds = (CGRect) { .size = node.calculatedSize };
  ASDisplayNodePerformBlockOnEveryNode(nil, node, ^(ASDisplayNode * _Nonnull node) {
    [node.layer setNeedsDisplay];
  });
  [node recursivelyEnsureDisplaySynchronously:YES];
}

@end
