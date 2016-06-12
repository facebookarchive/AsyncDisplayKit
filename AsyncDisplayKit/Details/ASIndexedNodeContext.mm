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

@interface ASIndexedNodeContext ()

/// Required node block used to allocate a cell node. Nil after the first execution.
@property (nonatomic, strong) ASCellNodeBlock nodeBlock;

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
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _constrainedSize = constrainedSize;
    _environmentTraitCollection = environmentTraitCollection;
  }
  return self;
}

- (ASCellNode *)allocateNode
{
  NSAssert(_nodeBlock != nil, @"Node block is gone. Should not execute it more than once");
  ASCellNode *node = _nodeBlock();
  _nodeBlock = nil;
  ASEnvironmentStatePropagateDown(node, _environmentTraitCollection);
  return node;
}

@end
