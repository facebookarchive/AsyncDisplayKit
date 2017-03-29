//
//  ASLayoutTransition.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 3/8/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutTransition.h>

#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/NSArray+Diffing.h>

#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h> // Required for _insertSubnode... / _removeFromSupernode.

#import <queue>
#import <memory>

#import <AsyncDisplayKit/ASThread.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>

/**
 * Search the whole layout stack if at least one layout has a layoutElement object that can not be layed out asynchronous.
 * This can be the case for example if a node was already loaded
 */
static inline BOOL ASLayoutCanTransitionAsynchronous(ASLayout *layout) {
  // Queue used to keep track of sublayouts while traversing this layout in a BFS fashion.
  std::queue<ASLayout *> queue;
  queue.push(layout);
  
  while (!queue.empty()) {
    layout = queue.front();
    queue.pop();
    
#if DEBUG
    ASDisplayNodeCAssert([layout.layoutElement conformsToProtocol:@protocol(ASLayoutElementTransition)], @"ASLayoutElement in a layout transition needs to conforms to the ASLayoutElementTransition protocol.");
#endif
    if (((id<ASLayoutElementTransition>)layout.layoutElement).canLayoutAsynchronous == NO) {
      return NO;
    }
    
    // Add all sublayouts to process in next step
    for (ASLayout *sublayout in layout.sublayouts) {
      queue.push(sublayout);
    }
  }
  
  return YES;
}

@implementation ASLayoutTransition {
  std::shared_ptr<ASDN::RecursiveMutex> __instanceLock__;
  
  BOOL _calculatedSubnodeOperations;
  NSArray<ASDisplayNode *> *_insertedSubnodes;
  NSArray<ASDisplayNode *> *_removedSubnodes;
  std::vector<NSUInteger> _insertedSubnodePositions;
  std::vector<NSUInteger> _removedSubnodePositions;
}

- (instancetype)initWithNode:(ASDisplayNode *)node
               pendingLayout:(std::shared_ptr<ASDisplayNodeLayout>)pendingLayout
              previousLayout:(std::shared_ptr<ASDisplayNodeLayout>)previousLayout
{
  self = [super init];
  if (self) {
    __instanceLock__ = std::make_shared<ASDN::RecursiveMutex>();
      
    _node = node;
    _pendingLayout = pendingLayout;
    _previousLayout = previousLayout;
  }
  return self;
}

- (instancetype)init
{
  ASDisplayNodeAssert(NO, @"Use the designated initializer");
  return [self init];
}

- (BOOL)isSynchronous
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  return !ASLayoutCanTransitionAsynchronous(_pendingLayout->layout);
}

- (void)commitTransition
{
  [self applySubnodeInsertions];
  [self applySubnodeRemovals];
}

- (void)applySubnodeInsertions
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  [self calculateSubnodeOperationsIfNeeded];
  
  if (_insertedSubnodes.count == 0) {
    return;
  }

  ASDisplayNodeLogEvent(_node, @"insertSubnodes: %@", _insertedSubnodes);
  NSUInteger i = 0;
  for (ASDisplayNode *node in _insertedSubnodes) {
    NSUInteger p = _insertedSubnodePositions[i];
    [_node _insertSubnode:node atIndex:p];
    i += 1;
  }
}

- (void)applySubnodeRemovals
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  [self calculateSubnodeOperationsIfNeeded];

  if (_removedSubnodes.count == 0) {
    return;
  }

  ASDisplayNodeLogEvent(_node, @"removeSubnodes: %@", _removedSubnodes);
  for (ASDisplayNode *subnode in _removedSubnodes) {
    // In this case we should only remove the subnode if it's still a subnode of the _node that executes a layout transition.
    // It can happen that a node already did a layout transition and added this subnode, in this case the subnode
    // would be removed from the new node instead of _node
    [subnode _removeFromSupernodeIfEqualTo:_node];
  }
}

- (void)calculateSubnodeOperationsIfNeeded
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  if (_calculatedSubnodeOperations) {
    return;
  }
  
  ASLayout *previousLayout = _previousLayout->layout;
  ASLayout *pendingLayout = _pendingLayout->layout;

  if (previousLayout) {
    NSIndexSet *insertions, *deletions;
    [previousLayout.sublayouts asdk_diffWithArray:pendingLayout.sublayouts
                                       insertions:&insertions
                                        deletions:&deletions
                                     compareBlock:^BOOL(ASLayout *lhs, ASLayout *rhs) {
                                       return ASObjectIsEqual(lhs.layoutElement, rhs.layoutElement);
                                     }];
    _insertedSubnodePositions = findNodesInLayoutAtIndexes(pendingLayout, insertions, &_insertedSubnodes);
    _removedSubnodePositions = findNodesInLayoutAtIndexesWithFilteredNodes(previousLayout,
                                                                           deletions,
                                                                           _insertedSubnodes,
                                                                           &_removedSubnodes);
  } else {
    NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [pendingLayout.sublayouts count])];
    _insertedSubnodePositions = findNodesInLayoutAtIndexes(pendingLayout, indexes, &_insertedSubnodes);
    _removedSubnodes = nil;
    _removedSubnodePositions.clear();
  }
  _calculatedSubnodeOperations = YES;
}

#pragma mark - _ASTransitionContextDelegate

- (NSArray<ASDisplayNode *> *)currentSubnodesWithTransitionContext:(_ASTransitionContext *)context
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  return _node.subnodes;
}

- (NSArray<ASDisplayNode *> *)insertedSubnodesWithTransitionContext:(_ASTransitionContext *)context
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  [self calculateSubnodeOperationsIfNeeded];
  return _insertedSubnodes;
}

- (NSArray<ASDisplayNode *> *)removedSubnodesWithTransitionContext:(_ASTransitionContext *)context
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  [self calculateSubnodeOperationsIfNeeded];
  return _removedSubnodes;
}

- (ASLayout *)transitionContext:(_ASTransitionContext *)context layoutForKey:(NSString *)key
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  if ([key isEqualToString:ASTransitionContextFromLayoutKey]) {
    return _previousLayout->layout;
  } else if ([key isEqualToString:ASTransitionContextToLayoutKey]) {
    return _pendingLayout->layout;
  } else {
    return nil;
  }
}

- (ASSizeRange)transitionContext:(_ASTransitionContext *)context constrainedSizeForKey:(NSString *)key
{
  ASDN::MutexSharedLocker l(__instanceLock__);
  if ([key isEqualToString:ASTransitionContextFromLayoutKey]) {
    return _previousLayout->constrainedSize;
  } else if ([key isEqualToString:ASTransitionContextToLayoutKey]) {
    return _pendingLayout->constrainedSize;
  } else {
    return ASSizeRangeMake(CGSizeZero, CGSizeZero);
  }
}

#pragma mark - Filter helpers

/**
 * @abstract Stores the nodes at the given indexes in the `storedNodes` array, storing indexes in a `storedPositions` c++ vector.
 */
static inline std::vector<NSUInteger> findNodesInLayoutAtIndexes(ASLayout *layout,
                                                                 NSIndexSet *indexes,
                                                                 NSArray<ASDisplayNode *> * __strong *storedNodes)
{
  return findNodesInLayoutAtIndexesWithFilteredNodes(layout, indexes, nil, storedNodes);
}

/**
 * @abstract Stores the nodes at the given indexes in the `storedNodes` array, storing indexes in a `storedPositions` c++ vector.
 * @discussion If the node exists in the `filteredNodes` array, the node is not added to `storedNodes`.
 */
static inline std::vector<NSUInteger> findNodesInLayoutAtIndexesWithFilteredNodes(ASLayout *layout,
                                                                                  NSIndexSet *indexes,
                                                                                  NSArray<ASDisplayNode *> *filteredNodes,
                                                                                  NSArray<ASDisplayNode *> * __strong *storedNodes)
{
  NSMutableArray<ASDisplayNode *> *nodes = [NSMutableArray arrayWithCapacity:indexes.count];
  std::vector<NSUInteger> positions = std::vector<NSUInteger>();
  
  // From inspection, this is how enumerateObjectsAtIndexes: works under the hood
  NSUInteger firstIndex = indexes.firstIndex;
  NSUInteger lastIndex = indexes.lastIndex;
  NSUInteger idx = 0;
  for (ASLayout *sublayout in layout.sublayouts) {
    if (idx > lastIndex) { break; }
    if (idx >= firstIndex && [indexes containsIndex:idx]) {
      ASDisplayNode *node = (ASDisplayNode *)sublayout.layoutElement;
      ASDisplayNodeCAssert(node, @"ASDisplayNode was deallocated before it was added to a subnode. It's likely the case that you use automatically manages subnodes and allocate a ASDisplayNode in layoutSpecThatFits: and don't have any strong reference to it.");
      // Ignore the odd case in which a non-node sublayout is accessed and the type cast fails
      if (node != nil) {
        BOOL notFiltered = (filteredNodes == nil || [filteredNodes indexOfObjectIdenticalTo:node] == NSNotFound);
        if (notFiltered) {
          [nodes addObject:node];
          positions.push_back(idx);
        }
      }
    }
    idx += 1;
  }
  *storedNodes = nodes;
  
  return positions;
}

@end
