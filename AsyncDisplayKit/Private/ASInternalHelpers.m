//
//  ASInternalHelpers.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASInternalHelpers.h"
#import "ASRunLoopQueue.h"

#import <objc/runtime.h>

#import "ASThread.h"
#import <tgmath.h>

BOOL ASSubclassOverridesSelector(Class superclass, Class subclass, SEL selector)
{
  if (superclass == subclass) return NO; // Even if the class implements the selector, it doesn't override itself.
  Method superclassMethod = class_getInstanceMethod(superclass, selector);
  Method subclassMethod = class_getInstanceMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;
  return (superclassIMP != subclassIMP);
}

BOOL ASSubclassOverridesClassSelector(Class superclass, Class subclass, SEL selector)
{
  if (superclass == subclass) return NO; // Even if the class implements the selector, it doesn't override itself.
  Method superclassMethod = class_getClassMethod(superclass, selector);
  Method subclassMethod = class_getClassMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;
  return (superclassIMP != subclassIMP);
}

IMP ASReplaceMethodWithBlock(Class c, SEL origSEL, id block)
{
  NSCParameterAssert(block);
  
  // Get original method
  Method origMethod = class_getInstanceMethod(c, origSEL);
  NSCParameterAssert(origMethod);
  
  // Convert block to IMP trampoline and replace method implementation
  IMP newIMP = imp_implementationWithBlock(block);
  
  // Try adding the method if not yet in the current class
  if (!class_addMethod(c, origSEL, newIMP, method_getTypeEncoding(origMethod))) {
    return method_setImplementation(origMethod, newIMP);
  } else {
    return method_getImplementation(origMethod);
  }
}

void ASPerformBlockOnMainThread(void (^block)())
{
  if (block == nil){
    return;
  }
  if (ASDisplayNodeThreadIsMain()) {
    block();
  } else {
    dispatch_async(dispatch_get_main_queue(), block);
  }
}

void ASPerformBlockOnBackgroundThread(void (^block)())
{
  if (block == nil){
    return;
  }
  if (ASDisplayNodeThreadIsMain()) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
  } else {
    block();
  }
}

void ASPerformBackgroundDeallocation(id object)
{
  [[ASDeallocQueue sharedDeallocationQueue] releaseObjectInBackground:object];
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
  CGFloat scale = ASScreenScale();
  return floor(f * scale) / scale;
}

CGFloat ASCeilPixelValue(CGFloat f)
{
  CGFloat scale = ASScreenScale();
  return ceil(f * scale) / scale;
}

CGFloat ASRoundPixelValue(CGFloat f)
{
  CGFloat scale = ASScreenScale();
  return round(f * scale) / scale;
}

@implementation NSIndexPath (ASInverseComparison)

- (NSComparisonResult)asdk_inverseCompare:(NSIndexPath *)otherIndexPath
{
  return [otherIndexPath compare:self];
}

@end
