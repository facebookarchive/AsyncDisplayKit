//
//  ASIndexedNodeContext.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASIndexedNodeContext.h"

@implementation ASIndexedNodeContext

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize;
{
  self = [super init];
  if (self) {
    _nodeBlock = nodeBlock;
    _indexPath = indexPath;
    _constrainedSize = constrainedSize;
  }
  return self;
}

@end
