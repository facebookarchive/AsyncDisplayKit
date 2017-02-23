//
//  ASRectTable.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/22/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASRectTable.h"

static NSUInteger ASSizeOfRect(const void *ptr) {
  return sizeof(CGRect);
};

@implementation ASRectTable

+ (ASRectTable *)rectTableWithKeyOptions:(NSPointerFunctionsOptions)keyOptions
{
  static NSPointerFunctions *rectValueFunctions;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    rectValueFunctions = [NSPointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsCopyIn | NSPointerFunctionsMallocMemory | NSPointerFunctionsStructPersonality];
    rectValueFunctions.sizeFunction = &ASSizeOfRect;
  });
  NSPointerFunctions *keyFunctions = [NSPointerFunctions pointerFunctionsWithOptions:keyOptions];
  return [[ASRectTable alloc] initWithKeyPointerFunctions:keyFunctions valuePointerFunctions:rectValueFunctions capacity:0];
}

- (CGRect)rectForKey:(id)key
{
  CGRect *src = (__bridge CGRect *)[self objectForKey:key];
  CGRect result = CGRectNull;
  if (src) {
    result = *src;
  }
  return result;
}

- (void)setRect:(CGRect)rect forKey:(id)key
{
  [self setObject:(__bridge id)(void *)&rect forKey:key];
}


@end
