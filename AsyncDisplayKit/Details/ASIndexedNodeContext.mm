//
//  ASIndexedNodeContext.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASIndexedNodeContext.h"
#import "ASEnvironmentInternal.h"
#import "ASCellNode.h"
#import "ASLayout.h"

@interface ASIndexedNodeContext ()

@property (atomic, nullable, strong) ASCellNode *node;

@end

@implementation ASIndexedNodeContext

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  NSAssert(nodeBlock != nil && indexPath != nil, @"Node block and index path must not be nil");
  self = [super init];
  if (self) {
    _indexPath = indexPath;

    __weak __typeof(self) weakSelf = self;
    _nodeCreationOperation = [NSBlockOperation blockOperationWithBlock:^{
      __strong ASIndexedNodeContext *self = weakSelf;
      if (self == nil) {
        return;
      }

      // Allocate the node.
      ASCellNode *node = nodeBlock();
      if (node == nil) {
        ASDisplayNodeAssertNotNil(node, @"Node block created nil node. indexPath: %@", indexPath);
        node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
      }

      // Propagate environment state down.
      ASEnvironmentStatePropagateDown(node, environmentTraitCollection);

      // Measure the node.
      CGRect frame = CGRectZero;
      frame.size = [node layoutThatFits:constrainedSize].size;
      node.frame = frame;

      // Set the resulting node on self.
      self.node = node;
    }];
  }
  return self;
}

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:contexts.count];
  for (ASIndexedNodeContext *ctx in contexts) {
    [result addObject:ctx.indexPath];
  }
  return result;
}

@end
