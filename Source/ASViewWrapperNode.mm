//
//  ASViewWrapperNode.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 3/23/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASViewWrapperNode.h"
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>

@implementation ASViewWrapperNode

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  if (self = [super init]) {
    _viewBlock = viewBlock;
    _flags.synchronous = YES;
  }
  return self;
}

@end
