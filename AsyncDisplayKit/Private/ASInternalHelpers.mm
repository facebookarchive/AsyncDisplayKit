/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "ASInternalHelpers.h"

#import <functional>
#import <objc/runtime.h>

#import "ASThread.h"
#import "ASLayout.h"

BOOL ASSubclassOverridesSelector(Class superclass, Class subclass, SEL selector)
{
  Method superclassMethod = class_getInstanceMethod(superclass, selector);
  Method subclassMethod = class_getInstanceMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;
  return (superclassIMP != subclassIMP);
}

BOOL ASSubclassOverridesClassSelector(Class superclass, Class subclass, SEL selector)
{
  Method superclassMethod = class_getClassMethod(superclass, selector);
  Method subclassMethod = class_getClassMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;
  return (superclassIMP != subclassIMP);
}

void ASPerformBlockOnMainThread(void (^block)())
{
  if (ASDisplayNodeThreadIsMain()) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

void ASPerformBlockOnBackgroundThread(void (^block)())
{
  if (ASDisplayNodeThreadIsMain()) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
  } else {
    block();
  }
}

CGFloat ASScreenScale()
{
  static CGFloat __scale = 0.0;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ASDisplayNodeCAssertMainThread();
    __scale = [[UIScreen mainScreen] scale];
  });
  return __scale;
}

CGFloat ASFloorPixelValue(CGFloat f)
{
  return floorf(f * ASScreenScale()) / ASScreenScale();
}

CGFloat ASCeilPixelValue(CGFloat f)
{
  return ceilf(f * ASScreenScale()) / ASScreenScale();
}

CGFloat ASRoundPixelValue(CGFloat f)
{
  return roundf(f * ASScreenScale()) / ASScreenScale();
}

BOOL ASRunningOnOS7()
{
  static BOOL isOS7 = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    isOS7 = ([[UIDevice currentDevice].systemVersion floatValue] < 8.0);
  });
  return isOS7;
}

@implementation NSIndexPath (ASInverseComparison)

- (NSComparisonResult)asdk_inverseCompare:(NSIndexPath *)otherIndexPath
{
  return [otherIndexPath compare:self];
}

@end
