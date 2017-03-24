//
//  ASLayerWrapperNode.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 3/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASLayerWrapperNode.h"
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>

@implementation ASLayerWrapperNode

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  if (self = [super init]) {
    _layerBlock = layerBlock;
    _flags.layerBacked = YES;
    _flags.synchronous = YES;
  }
  return self;
}

@end
