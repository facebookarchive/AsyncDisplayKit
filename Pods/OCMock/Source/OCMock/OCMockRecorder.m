//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import <OCMock/OCMockRecorder.h>
#import <OCMock/OCMArg.h>
#import <OCMock/OCMConstraint.h>
#import "OCClassMockObject.h"
#import "OCMPassByRefSetter.h"
#import "OCMReturnValueProvider.h"
#import "OCMBoxedReturnValueProvider.h"
#import "OCMExceptionReturnValueProvider.h"
#import "OCMIndirectReturnValueProvider.h"
#import "OCMNotificationPoster.h"
#import "OCMBlockCaller.h"
#import "OCMRealObjectForwarder.h"
#import "NSInvocation+OCMAdditions.h"

@interface NSObject(HCMatcherDummy)
- (BOOL)matches:(id)item;
@end

#pragma mark  -


@implementation OCMockRecorder

#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithSignatureResolver:(id)anObject
{
	signatureResolver = anObject;
	invocationHandlers = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	[recordedInvocation release];
	[invocationHandlers release];
	[super dealloc];
}

- (NSString *)description
{
	return [recordedInvocation invocationDescription];
}

- (void)releaseInvocation
{
	[recordedInvocation release];
	recordedInvocation = nil;
}


#pragma mark  Recording invocation handlers

- (id)andReturn:(id)anObject
{
	[invocationHandlers addObject:[[[OCMReturnValueProvider alloc] initWithValue:anObject] autorelease]];
	return self;
}

- (id)andReturnValue:(NSValue *)aValue
{
	[invocationHandlers addObject:[[[OCMBoxedReturnValueProvider alloc] initWithValue:aValue] autorelease]];
	return self;
}

- (id)andThrow:(NSException *)anException
{
	[invocationHandlers addObject:[[[OCMExceptionReturnValueProvider alloc] initWithValue:anException] autorelease]];
	return self;
}

- (id)andPost:(NSNotification *)aNotification
{
	[invocationHandlers addObject:[[[OCMNotificationPoster alloc] initWithNotification:aNotification] autorelease]];
	return self;
}

- (id)andCall:(SEL)selector onObject:(id)anObject
{
	[invocationHandlers addObject:[[[OCMIndirectReturnValueProvider alloc] initWithProvider:anObject andSelector:selector] autorelease]];
	return self;
}

#if NS_BLOCKS_AVAILABLE

- (id)andDo:(void (^)(NSInvocation *))aBlock 
{
	[invocationHandlers addObject:[[[OCMBlockCaller alloc] initWithCallBlock:aBlock] autorelease]];
	return self;
}

#endif

- (id)andForwardToRealObject
{
    [invocationHandlers addObject:[[[OCMRealObjectForwarder alloc] init] autorelease]];
    return self;
}


- (NSArray *)invocationHandlers
{
	return invocationHandlers;
}


#pragma mark  Modifying the recorder

- (id)classMethod
{
    recordedAsClassMethod = YES;
    [signatureResolver setupClassForClassMethodMocking];
    return self;
}

- (id)ignoringNonObjectArgs
{
    ignoreNonObjectArgs = YES;
    return self;
}


#pragma mark  Recording the actual invocation

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    if(recordedAsClassMethod)
        return [[signatureResolver mockedClass] methodSignatureForSelector:aSelector];
    
    NSMethodSignature *signature = [signatureResolver methodSignatureForSelector:aSelector];
    if(signature == nil)
    {
        // if we're a working with a class mock and there is a class method, auto-switch
        if(([object_getClass(signatureResolver) isSubclassOfClass:[OCClassMockObject class]]) &&
           ([[signatureResolver mockedClass] respondsToSelector:aSelector]))
        {
            [self classMethod];
            signature = [self methodSignatureForSelector:aSelector];
        }
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if(recordedAsClassMethod)
        [signatureResolver setupForwarderForClassMethodSelector:[anInvocation selector]];
	if(recordedInvocation != nil)
		[NSException raise:NSInternalInconsistencyException format:@"Recorder received two methods to record."];
	[anInvocation setTarget:nil];
	[anInvocation retainArguments];
	recordedInvocation = [anInvocation retain];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    [NSException raise:NSInvalidArgumentException format:@"%@: cannot stub or expect method '%@' because no such method exists in the mocked class.", signatureResolver, NSStringFromSelector(aSelector)];
}

#pragma mark  Checking the invocation

- (BOOL)matchesSelector:(SEL)sel
{
    return (sel == [recordedInvocation selector]);
}

- (BOOL)matchesInvocation:(NSInvocation *)anInvocation
{
    id target = [anInvocation target];
    BOOL isClassMethodInvocation = (target != nil) && (target == [target class]);
    if(isClassMethodInvocation != recordedAsClassMethod)
        return NO;
    
	if([anInvocation selector] != [recordedInvocation selector])
		return NO;

    NSMethodSignature *signature = [recordedInvocation methodSignature];
    int n = (int)[signature numberOfArguments];
	for(int i = 2; i < n; i++)
	{
        if(ignoreNonObjectArgs && strcmp([signature getArgumentTypeAtIndex:i], @encode(id)))
        {
            continue;
        }

		id recordedArg = [recordedInvocation getArgumentAtIndexAsObject:i];
		id passedArg = [anInvocation getArgumentAtIndexAsObject:i];

		if([recordedArg isProxy])
		{
			if(![recordedArg isEqual:passedArg])
				return NO;
			continue;
		}
		
		if([recordedArg isKindOfClass:[NSValue class]])
			recordedArg = [OCMArg resolveSpecialValues:recordedArg];
		
		if([recordedArg isKindOfClass:[OCMConstraint class]])
		{	
			if([recordedArg evaluate:passedArg] == NO)
				return NO;
		}
		else if([recordedArg isKindOfClass:[OCMPassByRefSetter class]])
		{
            id valueToSet = [(OCMPassByRefSetter *)recordedArg value];
			// side effect but easier to do here than in handleInvocation
            if(![valueToSet isKindOfClass:[NSValue class]])
                *(id *)[passedArg pointerValue] = valueToSet;
            else
                [(NSValue *)valueToSet getValue:[passedArg pointerValue]];
		}
		else if([recordedArg conformsToProtocol:objc_getProtocol("HCMatcher")])
		{
			if([recordedArg matches:passedArg] == NO)
				return NO;
		}
		else
		{
			if(([recordedArg class] == [NSNumber class]) && 
				([(NSNumber*)recordedArg compare:(NSNumber*)passedArg] != NSOrderedSame))
				return NO;
			if(([recordedArg isEqual:passedArg] == NO) &&
				!((recordedArg == nil) && (passedArg == nil)))
				return NO;
		}
	}
	return YES;
}


@end
