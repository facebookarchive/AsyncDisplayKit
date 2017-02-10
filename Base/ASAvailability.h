//
//  ASAvailability.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <CoreFoundation/CFBase.h>

#pragma once

#ifndef kCFCoreFoundationVersionNumber_iOS_9_0
  #define kCFCoreFoundationVersionNumber_iOS_9_0 1240.10
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_10_0
  #define kCFCoreFoundationVersionNumber_iOS_10_0 1348.00
#endif

#define AS_AT_LEAST_IOS9   (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_9_0)
#define AS_AT_LEAST_IOS10  (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_10_0)

#define AS_TARGET_OS_OSX (!(TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_WATCH))
#define AS_TARGET_OS_IOS TARGET_OS_IPHONE

// If Yoga is available, make it available anywhere we use ASAvailability.
// This reduces Yoga-specific code in other files.// If Yoga is available, make it available anywhere we use ASAvailability.
#if __has_include(<Yoga/Yoga.h>)
#define YOGA 1
#endif

#if AS_TARGET_OS_OSX

#define UIEdgeInsets NSEdgeInsets
#define NSStringFromCGSize NSStringFromSize
#define NSStringFromCGPoint NSStringFromPoint

#import <Foundation/Foundation.h>

@interface NSValue (ASAvailability)
+ (NSValue *)valueWithCGPoint:(CGPoint)point;
+ (NSValue *)valueWithCGSize:(CGSize)size;
- (CGRect)CGRectValue;
- (CGPoint)CGPointValue;
- (CGSize)CGSizeValue;
@end

@implementation NSValue(ASAvailability)
+ (NSValue *)valueWithCGPoint:(CGPoint)point
{
  return [self valueWithPoint:point];
}
+ (NSValue *)valueWithCGSize:(CGSize)size
{
  return [self valueWithSize:size];
}
- (CGRect)CGRectValue
{
  return self.rectValue;
}

- (CGPoint)CGPointValue
{
  return self.pointValue;
}

- (CGSize)CGSizeValue
{
  return self.sizeValue;
}
@end

#endif
