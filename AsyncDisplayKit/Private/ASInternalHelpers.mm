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

#import "ASLayout.h"

BOOL ASSubclassOverridesSelector(Class superclass, Class subclass, SEL selector)
{
  Method superclassMethod = class_getInstanceMethod(superclass, selector);
  Method subclassMethod = class_getInstanceMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;
  return (superclassIMP != subclassIMP);
}

static void ASDispatchOnceOnMainThread(dispatch_once_t *predicate, dispatch_block_t block)
{
  if ([NSThread isMainThread]) {
    dispatch_once(predicate, block);
  } else {
    if (DISPATCH_EXPECT(*predicate == 0L, NO)) {
      dispatch_sync(dispatch_get_main_queue(), ^{
        dispatch_once(predicate, block);
      });
    }
  }
}

CGFloat ASScreenScale()
{
  static CGFloat _scale;
  static dispatch_once_t onceToken;
  ASDispatchOnceOnMainThread(&onceToken, ^{
    _scale = [UIScreen mainScreen].scale;
  });
  return _scale;
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
