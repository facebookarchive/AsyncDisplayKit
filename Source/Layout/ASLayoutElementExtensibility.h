//
//  ASLayoutElementExtensibility.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 3/29/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIGeometry.h>

#import <objc/runtime.h>

#pragma mark - ASLayoutElementExtensibility

@protocol ASLayoutElementExtensibility <NSObject>

// The maximum number of extended values per type are defined in ASEnvironment.h above the ASEnvironmentStateExtensions
// struct definition. If you try to set a value at an index after the maximum it will throw an assertion.

- (void)setLayoutOptionExtensionBool:(BOOL)value atIndex:(int)idx;
- (BOOL)layoutOptionExtensionBoolAtIndex:(int)idx;

- (void)setLayoutOptionExtensionInteger:(NSInteger)value atIndex:(int)idx;
- (NSInteger)layoutOptionExtensionIntegerAtIndex:(int)idx;

- (void)setLayoutOptionExtensionEdgeInsets:(UIEdgeInsets)value atIndex:(int)idx;
- (UIEdgeInsets)layoutOptionExtensionEdgeInsetsAtIndex:(int)idx;

@end

#pragma mark - Dynamic Properties

/**
 * Unbox NSNumber based on the type
 */
#define ASDK_UNBOX_NUMBER(NUMBER, PROPERTY_TYPE) \
const char *objCType = [NUMBER objCType]; \
if (strcmp(objCType, @encode(BOOL)) == 0) { \
  return (PROPERTY_TYPE)[obj boolValue]; \
} else if (strcmp(objCType, @encode(int)) == 0) { \
  return (PROPERTY_TYPE)[obj intValue]; \
} else if (strcmp(objCType, @encode(NSInteger)) == 0) { \
  return (PROPERTY_TYPE)[obj integerValue]; \
} else if (strcmp(objCType, @encode(NSUInteger)) == 0) { \
  return (PROPERTY_TYPE)[obj unsignedIntegerValue]; \
} else if (strcmp(objCType, @encode(CGFloat)) == 0) { \
  return (PROPERTY_TYPE)[obj floatValue]; \
} else { \
  NSAssert(NO, @"Data type not supported"); \
} \

/**
 * Define a NSObject property
 */
#define ASDK_STYLE_PROP_OBJ(PROPERTY_TYPE, PROPERTY_NAME, SETTER_NAME) \
@dynamic PROPERTY_NAME; \
- (PROPERTY_TYPE)PROPERTY_NAME \
{ \
  return (PROPERTY_TYPE)objc_getAssociatedObject(self, @selector(PROPERTY_NAME)); \
} \
\
- (void)SETTER_NAME:(PROPERTY_TYPE)PROPERTY_NAME \
{ \
  objc_setAssociatedObject(self, @selector(PROPERTY_NAME), PROPERTY_NAME, OBJC_ASSOCIATION_RETAIN); \
} \

/**
 * Define an primitive property
 */
#define ASDK_STYLE_PROP_PRIM(PROPERTY_TYPE, PROPERTY_NAME, SETTER_NAME, DEFAULT_VALUE) \
@dynamic PROPERTY_NAME; \
- (PROPERTY_TYPE)PROPERTY_NAME \
{ \
  id obj = objc_getAssociatedObject(self, @selector(PROPERTY_NAME)); \
  \
  if (obj != nil) { \
    ASDK_UNBOX_NUMBER(obj, PROPERTY_TYPE); \
  } \
  \
  return DEFAULT_VALUE;\
} \
\
- (void)SETTER_NAME:(PROPERTY_TYPE)PROPERTY_NAME \
{ \
  objc_setAssociatedObject(self, @selector(PROPERTY_NAME), @(PROPERTY_NAME), OBJC_ASSOCIATION_RETAIN); \
} \

/**
 * Define an structure property
 */
#define ASDK_STYLE_PROP_STR(PROPERTY_TYPE, PROPERTY_NAME, SETTER_NAME, DEFAULT_STRUCT) \
@dynamic PROPERTY_NAME; \
- (PROPERTY_TYPE)PROPERTY_NAME \
{ \
  id obj = objc_getAssociatedObject(self, @selector(PROPERTY_NAME)); \
  if (obj == nil) { \
    return DEFAULT_STRUCT; \
  } \
  PROPERTY_TYPE PROPERTY_NAME; [obj getValue:&PROPERTY_NAME]; return PROPERTY_NAME; \
} \
\
- (void)SETTER_NAME:(PROPERTY_TYPE)PROPERTY_NAME \
{ \
  objc_setAssociatedObject(self, @selector(PROPERTY_NAME), [NSValue value:&PROPERTY_NAME withObjCType:@encode(PROPERTY_TYPE)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
} \
