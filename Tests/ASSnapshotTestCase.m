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
#import <AsyncDisplayKit/ASAvailability.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

NSOrderedSet *ASSnapshotTestCaseDefaultSuffixes(void)
{
  NSMutableOrderedSet *suffixesSet = [[NSMutableOrderedSet alloc] init];
  // In some rare cases, slightly different rendering may occur on iOS 10 (text rasterization).
  // If the test folders find any image that exactly matches, they pass;
  // if an image is not present at all, or it fails, it moves on to check the others.
  // This means the order doesn't matter besides reducing logging / performance.
  if (AS_AT_LEAST_IOS10) {
    [suffixesSet addObject:@"_iOS_10"];
  }
  [suffixesSet addObject:@"_64"];
  return [suffixesSet copy];
}

@implementation ASSnapshotTestCase

+ (void)hackilySynchronouslyRecursivelyRenderNode:(ASDisplayNode *)node
{
  ASDisplayNodePerformBlockOnEveryNode(nil, node, YES, ^(ASDisplayNode * _Nonnull node) {
    [node.layer setNeedsDisplay];
  });
  [node recursivelyEnsureDisplaySynchronously:YES];
}

@end
