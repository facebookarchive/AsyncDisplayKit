//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMArg : NSObject 

// constraining arguments

+ (id)any;
+ (SEL)anySelector;
+ (void *)anyPointer;
+ (id __autoreleasing *)anyObjectRef;
+ (id)isNil;
+ (id)isNotNil;
+ (id)isNotEqual:(id)value;
+ (id)checkWithSelector:(SEL)selector onObject:(id)anObject;
#if NS_BLOCKS_AVAILABLE
+ (id)checkWithBlock:(BOOL (^)(id obj))block;
#endif

// manipulating arguments

+ (id *)setTo:(id)value;
+ (void *)setToValue:(NSValue *)value;

// internal use only

+ (id)resolveSpecialValues:(NSValue *)value;

@end

#define OCMOCK_ANY [OCMArg any]

#if defined(__GNUC__) && !defined(__STRICT_ANSI__)
  #define OCMOCK_VALUE(variable) \
    ({ __typeof__(variable) __v = (variable); [NSValue value:&__v withObjCType:@encode(__typeof__(__v))]; })
#else
  #define OCMOCK_VALUE(variable) [NSValue value:&variable withObjCType:@encode(__typeof__(variable))]
#endif
