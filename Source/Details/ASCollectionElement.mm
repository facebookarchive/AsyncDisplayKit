//
//  ASCollectionElement.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionElement.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>
#import <mutex>

@interface ASCollectionElement ()

/// Required node block used to allocate a cell node. Nil after the first execution.
@property (nonatomic, strong) ASCellNodeBlock nodeBlock;

@end

@implementation ASCollectionElement {
  std::mutex _lock;
  ASCellNode *_node;
}

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
         supplementaryElementKind:(NSString *)supplementaryElementKind
                  constrainedSize:(ASSizeRange)constrainedSize
                       owningNode:(ASDisplayNode *)owningNode
                  traitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  NSAssert(nodeBlock != nil, @"Node block must not be nil");
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _supplementaryElementKind = [supplementaryElementKind copy];
    _constrainedSize = constrainedSize;
    _owningNode = owningNode;
    _traitCollection = traitCollection;
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
      ASDisplayNodeFailAssert(@"Node block returned nil node!");
      node = [[ASCellNode alloc] init];
    }
    node.owningNode = _owningNode;
    node.collectionElement = self;
    ASTraitCollectionPropagateDown(node, _traitCollection);
    _node = node;
  }
  return _node;
}

- (ASCellNode *)nodeIfAllocated
{
  std::lock_guard<std::mutex> l(_lock);
  return _node;
}

- (void)setTraitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  ASCellNode *nodeIfNeedsPropagation;
  
  {
    std::lock_guard<std::mutex> l(_lock);
    if (! ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(_traitCollection, traitCollection)) {
      _traitCollection = traitCollection;
      nodeIfNeedsPropagation = _node;
    }
  }
  
  if (nodeIfNeedsPropagation != nil) {
    ASTraitCollectionPropagateDown(nodeIfNeedsPropagation, traitCollection);
  }
}

@end
