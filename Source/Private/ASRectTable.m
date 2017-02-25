//
//  ASRectTable.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASRectTable.h"

__attribute__((const))
static NSUInteger ASRectSize(const void *ptr)
{
  return sizeof(CGRect);
}

@implementation NSMapTable (ASRectTableMethods)

+ (instancetype)rectTableWithKeyPointerFunctions:(NSPointerFunctions *)keyFuncs
{
  static NSPointerFunctions *cgRectFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cgRectFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStructPersonality | NSPointerFunctionsCopyIn | NSPointerFunctionsMallocMemory];
    cgRectFuncs.sizeFunction = &ASRectSize;
  });

  return [[NSMapTable alloc] initWithKeyPointerFunctions:keyFuncs valuePointerFunctions:cgRectFuncs capacity:0];
}

+ (instancetype)rectTableForStrongObjectPointers
{
  static NSPointerFunctions *strongObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    strongObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsStrongMemory | NSPointerFunctionsObjectPointerPersonality];
  });
  return [self rectTableWithKeyPointerFunctions:strongObjectPointerFuncs];
}

+ (instancetype)rectTableForWeakObjectPointers
{
  static NSPointerFunctions *weakObjectPointerFuncs;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    weakObjectPointerFuncs = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
  });
  return [self rectTableWithKeyPointerFunctions:weakObjectPointerFuncs];
}

- (CGRect)rectForKey:(id)key
{
  CGRect *ptr = (__bridge CGRect *)[self objectForKey:key];
  if (ptr == NULL) {
    return CGRectNull;
  }
  return *ptr;
}

- (void)setRect:(CGRect)rect forKey:(id)key
{
  __unsafe_unretained id obj = (__bridge id)&rect;
  [self setObject:obj forKey:key];
}

- (void)removeRectForKey:(id)key
{
  [self removeObjectForKey:key];
}

@end
