//
//  ASDisplayNodeTipState.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDisplayNodeTipState.h"

@interface ASDisplayNodeTipState ()
@end

@implementation ASDisplayNodeTipState

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (self = [super init]) {
    _node = node;
  }
  return self;
}

@end
