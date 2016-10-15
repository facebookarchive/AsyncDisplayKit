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
#import "ASCellNode+Internal.h"
#import <mutex>

@interface ASIndexedNodeContext ()

/// Required node block used to allocate a cell node. Nil after the first execution.
@property (nonatomic, strong) ASCellNodeBlock nodeBlock;

@end

@implementation ASIndexedNodeContext {
  std::mutex _lock;
  ASCellNode *_node;
}

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
         supplementaryElementKind:(nullable NSString *)supplementaryElementKind
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  NSAssert(nodeBlock != nil && indexPath != nil, @"Node block and index path must not be nil");
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _supplementaryElementKind = [supplementaryElementKind copy];
    _constrainedSize = constrainedSize;
    _environmentTraitCollection = environmentTraitCollection;
  }
  return self;
}

- (ASCellNode *)node
{
  std::lock_guard<std::mutex> l(_lock);
  if (_nodeBlock != nil) {
    ASCellNode *node = _nodeBlock();
    _nodeBlock = nil;
    if (node == nil) {
      ASDisplayNodeFailAssert(@"Node block returned nil node! Index path: %@", _indexPath);
      node = [[ASCellNode alloc] init];
    }
    node.cachedIndexPath = _indexPath;
    node.supplementaryElementKind = _supplementaryElementKind;
    ASEnvironmentStatePropagateDown(node, _environmentTraitCollection);
    _node = node;
  }
  return _node;
}

- (ASCellNode *)nodeIfAllocated
{
  std::lock_guard<std::mutex> l(_lock);
  return _node;
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
