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
#import <stdatomic.h>

@interface ASIndexedNodeContext ()

/// A readwrite variant of the same public property.
@property (atomic, nullable, strong) ASCellNode *nodeIfMeasured;

/// Our operation, if one has been enqueued and is still alive.
@property (atomic, weak) NSOperation *nodeMeasurementOperation;

/// Required node block used to allocate a cell node. Nil after measurement.
@property (nonatomic, copy, nullable) ASCellNodeBlock nodeBlock;

@end

@implementation ASIndexedNodeContext {
  atomic_flag _hasEnqueuedOperation;

  // Input params – constant
  ASSizeRange _constrainedSize;
  ASEnvironmentTraitCollection _environmentTraitCollection;
}

+ (NSOperationQueue *)nodeMeasurementQueue
{
  static NSOperationQueue *nodeMeasurementQueue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    nodeMeasurementQueue = [[NSOperationQueue alloc] init];
    nodeMeasurementQueue.name = @"org.AsyncDisplayKit.cellNodeMeasurementQueue";
    nodeMeasurementQueue.maxConcurrentOperationCount = [NSProcessInfo processInfo].processorCount * 2;
  });
  return nodeMeasurementQueue;
}

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  NSAssert(nodeBlock != nil && indexPath != nil, @"Node block and index path must not be nil");
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _constrainedSize = constrainedSize;
    _environmentTraitCollection = environmentTraitCollection;
  }
  return self;
}

#pragma mark - Public API

- (void)beginMeasuringNode
{
  if (atomic_flag_test_and_set(&_hasEnqueuedOperation)) {
    return;
  }

  __weak __typeof(self) weakSelf = self;
  NSOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
    [weakSelf measureCellNodeOperationBody];
  }];
  self.nodeMeasurementOperation = operation;
  [[ASIndexedNodeContext nodeMeasurementQueue] addOperation:operation];
}

- (ASCellNode *)node
{
  [self _ensureNodeMeasured];
  return self.nodeIfMeasured;
}

#pragma mark - Private API

/**
 * This method is executed once per context, to perform the measurement.
 */
- (void)measureCellNodeOperationBody
{
  // Allocate the node.
  ASCellNode *node = self.nodeBlock();
  self.nodeBlock = nil;
  if (node == nil) {
    ASDisplayNodeAssertNotNil(node, @"Node block created nil node. indexPath: %@", _indexPath);
    node = [[ASCellNode alloc] init]; // Fallback to avoid crash for production apps.
  }

  // Propagate environment state down.
  ASEnvironmentStatePropagateDown(node, _environmentTraitCollection);

  // Measure the node.
  CGRect frame = CGRectZero;
  frame.size = [node layoutThatFits:_constrainedSize].size;
  node.frame = frame;

  // Set resulting node.
  self.nodeIfMeasured = node;
}

- (void)_ensureNodeMeasured
{
  [self beginMeasuringNode];
  [self.nodeMeasurementOperation waitUntilFinished];
}

#pragma mark - Helpers

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:contexts.count];
  for (ASIndexedNodeContext *ctx in contexts) {
    [result addObject:ctx.indexPath];
  }
  return result;
}

@end
