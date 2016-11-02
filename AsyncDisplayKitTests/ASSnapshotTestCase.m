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
#import "ASAvailability.h"
#import "ASDisplayNode+Beta.h"
#import "ASDisplayNodeExtras.h"
#import "ASDisplayNode+Subclasses.h"

NSOrderedSet *ASSnapshotTestCaseDefaultSuffixes(void)
{
  NSMutableOrderedSet *suffixesSet = [[NSMutableOrderedSet alloc] init];
  // In some rare cases, slightly different rendering may occur on 32 vs 64 bit architectures,
  // or on iOS 10 (text rasterization).  If the test folders find any image that exactly matches,
  // they pass; if an image is not present at all, or it fails, it moves on to check the others.
  // This means the order doesn't matter besides reducing logging / performance.
  [suffixesSet addObject:@"_32"];
  [suffixesSet addObject:@"_64"];
  if (AS_AT_LEAST_IOS10) {
    [suffixesSet addObject:@"_iOS_10"];
  }
#if __LP64__
  return [suffixesSet reversedOrderedSet];
#else
  return [suffixesSet copy];
#endif
}

@implementation ASSnapshotTestCase

+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertNotNil(node.calculatedLayout, @"Node %@ must be measured before it is rendered.", node);
  node.bounds = (CGRect) { .size = node.calculatedSize };
  ASDisplayNodePerformBlockOnEveryNode(nil, node, YES, ^(ASDisplayNode * _Nonnull node) {
    [node.layer setNeedsDisplay];
  });
  [node recursivelyEnsureDisplaySynchronously:YES];
}

@end
