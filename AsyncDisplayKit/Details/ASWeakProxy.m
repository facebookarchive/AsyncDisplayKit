//
//  ASWeakProxy.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASWeakProxy.h"

@implementation ASWeakProxy

- (instancetype)initWithTarget:(id)target
{
  if (self = [super init]) {
    _target = target;
  }
  return self;
}

+ (instancetype)weakProxyWithTarget:(id)target
{
  return [[ASWeakProxy alloc] initWithTarget:target];
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  return _target;
}

@end
