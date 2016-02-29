//
//  ASIndexedNodeContext.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASIndexedNodeContext.h"

@interface ASIndexedNodeContext ()

/// Required node block used to allocate a cell node. Nil after the first execution.
@property (nonatomic, strong) ASCellNodeBlock nodeBlock;

@end

@implementation ASIndexedNodeContext

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize;
{
  NSAssert(nodeBlock != nil && indexPath != nil, @"Node block and index path must not be nil");
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _constrainedSize = constrainedSize;
  }
  return self;
}

- (ASCellNode *)allocateNode
{
  NSAssert(_nodeBlock != nil, @"Node block is gone. Should not execute it more than once");
  ASCellNode *node = _nodeBlock();
  _nodeBlock = nil;
  return node;
}

@end
