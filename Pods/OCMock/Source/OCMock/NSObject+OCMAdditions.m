//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "NSObject+OCMAdditions.h"
#import "NSMethodSignature+OCMAdditions.h"
#import <objc/runtime.h>

@implementation NSObject(OCMAdditions)

+ (IMP)instanceMethodForwarderForSelector:(SEL)aSelector
{
    // use NSSelectorFromString and not @selector to avoid warning
    SEL selectorWithNoImplementation = NSSelectorFromString(@"methodWhichMustNotExist::::");

#ifndef __arm64__
    NSMethodSignature *sig = [self instanceMethodSignatureForSelector:aSelector];
    if([sig usesSpecialStructureReturn])
        return class_getMethodImplementation_stret(self, selectorWithNoImplementation);
#endif
    
    return class_getMethodImplementation(self, selectorWithNoImplementation);
}

@end