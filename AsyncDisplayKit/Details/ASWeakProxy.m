//
//  ASWeakProxy.m
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/12/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASWeakProxy.h"

@implementation ASWeakProxy

- (instancetype)initWithTarget:(id)target
{
  if (self) {
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

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
  // Check for a compiled definition for the selector
  NSMethodSignature *methodSignature = [[_target class] instanceMethodSignatureForSelector:aSelector];
  
  // Unfortunately, in order to get this object to work properly, the use of a method which creates an NSMethodSignature
  // from a C string. -methodSignatureForSelector is called when a compiled definition for the selector cannot be found.
  // This is the place where we have to create our own dud NSMethodSignature. This is necessary because if this method
  // returns nil, a selector not found exception is raised. The string argument to -signatureWithObjCTypes: outlines
  // the return type and arguments to the message. To return a dud NSMethodSignature, pretty much any signature will
  // suffice. Since the -forwardInvocation call will do nothing if the delegate does not respond to the selector,
  // the dud NSMethodSignature simply gets us around the exception.
  return methodSignature ?: [NSMethodSignature signatureWithObjCTypes:"@^v^c"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
  // If we are down here this means _target where nil. Just don't do anything to prevent a crash
}

@end
