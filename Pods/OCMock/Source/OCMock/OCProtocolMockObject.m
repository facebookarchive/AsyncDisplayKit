//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2005-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import "NSMethodSignature+OCMAdditions.h"
#import "OCProtocolMockObject.h"

@implementation OCProtocolMockObject

#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithProtocol:(Protocol *)aProtocol
{
	[super init];
	mockedProtocol = aProtocol;
	return self;
}

- (NSString *)description
{
    const char* name = protocol_getName(mockedProtocol);
    return [NSString stringWithFormat:@"OCMockObject[%s]", name];
}

#pragma mark  Proxy API

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	struct objc_method_description methodDescription = protocol_getMethodDescription(mockedProtocol, aSelector, YES, YES);
    if(methodDescription.name == NULL) 
	{
        methodDescription = protocol_getMethodDescription(mockedProtocol, aSelector, NO, YES);
    }
    if(methodDescription.name == NULL) 
	{
        return nil;
    }
	return [NSMethodSignature signatureWithObjCTypes:methodDescription.types];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    return protocol_conformsToProtocol(mockedProtocol, aProtocol);
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return ([self methodSignatureForSelector:selector] != nil);
}

@end
