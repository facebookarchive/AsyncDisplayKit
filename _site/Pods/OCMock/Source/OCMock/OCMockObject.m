//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <OCMock/OCMockObject.h>
#import "OCClassMockObject.h"
#import "OCProtocolMockObject.h"
#import "OCPartialMockObject.h"
#import "OCObserverMockObject.h"
#import <OCMock/OCMockRecorder.h>
#import "NSInvocation+OCMAdditions.h"


@interface OCMockObject(Private)
+ (id)_makeNice:(OCMockObject *)mock;
- (NSString *)_recorderDescriptions:(BOOL)onlyExpectations;
@end

#pragma mark  -


@implementation OCMockObject

#pragma mark  Class initialisation

+ (void)initialize
{
	if([[NSInvocation class] instanceMethodSignatureForSelector:@selector(getArgumentAtIndexAsObject:)] == NULL)
		[NSException raise:NSInternalInconsistencyException format:@"** Expected method not present; the method getArgumentAtIndexAsObject: is not implemented by NSInvocation. If you see this exception it is likely that you are using the static library version of OCMock and your project is not configured correctly to load categories from static libraries. Did you forget to add the -force_load linker flag?"];
}


#pragma mark  Factory methods

+ (id)mockForClass:(Class)aClass
{
	return [[[OCClassMockObject alloc] initWithClass:aClass] autorelease];
}

+ (id)mockForProtocol:(Protocol *)aProtocol
{
	return [[[OCProtocolMockObject alloc] initWithProtocol:aProtocol] autorelease];
}

+ (id)partialMockForObject:(NSObject *)anObject
{
	return [[[OCPartialMockObject alloc] initWithObject:anObject] autorelease];
}


+ (id)niceMockForClass:(Class)aClass
{
	return [self _makeNice:[self mockForClass:aClass]];
}

+ (id)niceMockForProtocol:(Protocol *)aProtocol
{
	return [self _makeNice:[self mockForProtocol:aProtocol]];
}


+ (id)_makeNice:(OCMockObject *)mock
{
	mock->isNice = YES;
	return mock;
}


+ (id)observerMock
{
	return [[[OCObserverMockObject alloc] init] autorelease];
}



#pragma mark  Initialisers, description, accessors, etc.

- (id)init
{
	// no [super init], we're inheriting from NSProxy
	expectationOrderMatters = NO;
	recorders = [[NSMutableArray alloc] init];
	expectations = [[NSMutableArray alloc] init];
	rejections = [[NSMutableArray alloc] init];
	exceptions = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	[recorders release];
	[expectations release];
	[rejections	release];
	[exceptions release];
	[super dealloc];
}

- (NSString *)description
{
	return @"OCMockObject";
}


- (void)setExpectationOrderMatters:(BOOL)flag
{
    expectationOrderMatters = flag;
}


#pragma mark  Public API

- (id)stub
{
	OCMockRecorder *recorder = [self getNewRecorder];
	[recorders addObject:recorder];
	return recorder;
}


- (id)expect
{
	OCMockRecorder *recorder = [self stub];
	[expectations addObject:recorder];
	return recorder;
}


- (id)reject
{
	OCMockRecorder *recorder = [self stub];
	[rejections addObject:recorder];
	return recorder;
}


- (void)verify
{
	if([expectations count] == 1)
	{
		[NSException raise:NSInternalInconsistencyException format:@"%@: expected method was not invoked: %@", 
			[self description], [[expectations objectAtIndex:0] description]];
	}
	if([expectations count] > 0)
	{
		[NSException raise:NSInternalInconsistencyException format:@"%@ : %@ expected methods were not invoked: %@", 
			[self description], @([expectations count]), [self _recorderDescriptions:YES]];
	}
	if([exceptions count] > 0)
	{
		[[exceptions objectAtIndex:0] raise];
	}
}

- (void)verifyWithDelay:(NSTimeInterval)delay
{
    NSTimeInterval step = 0.01;
    while(delay > 0)
    {
        if([expectations count] == 0)
            break;
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:step]];
        delay -= step;
        step *= 2;
    }
    [self verify];
}

- (void)stopMocking
{
    // no-op for mock objects that are not class object or partial mocks
}


#pragma mark  Handling invocations

- (BOOL)handleSelector:(SEL)sel
{
    for (OCMockRecorder *recorder in recorders)
        if ([recorder matchesSelector:sel])
            return YES;

    return NO;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	if([self handleInvocation:anInvocation] == NO)
		[self handleUnRecordedInvocation:anInvocation];
}

- (BOOL)handleInvocation:(NSInvocation *)anInvocation
{
	OCMockRecorder *recorder = nil;
	unsigned int			   i;
	
	for(i = 0; i < [recorders count]; i++)
	{
		recorder = [recorders objectAtIndex:i];
		if([recorder matchesInvocation:anInvocation])
			break;
	}
	
	if(i == [recorders count])
		return NO;
	
	if([rejections containsObject:recorder]) 
	{
		NSException *exception = [NSException exceptionWithName:NSInternalInconsistencyException reason:
								  [NSString stringWithFormat:@"%@: explicitly disallowed method invoked: %@", [self description], 
								   [anInvocation invocationDescription]] userInfo:nil];
		[exceptions addObject:exception];
		[exception raise];
	}

	if([expectations containsObject:recorder])
	{
		if(expectationOrderMatters && ([expectations objectAtIndex:0] != recorder))
		{
			[NSException raise:NSInternalInconsistencyException	format:@"%@: unexpected method invoked: %@\n\texpected:\t%@",  
			 [self description], [recorder description], [[expectations objectAtIndex:0] description]];
			
		}
		[[recorder retain] autorelease];
		[expectations removeObject:recorder];
		[recorders removeObjectAtIndex:i];
	}
	[[recorder invocationHandlers] makeObjectsPerformSelector:@selector(handleInvocation:) withObject:anInvocation];
	
	return YES;
}

- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation
{
	if(isNice == NO)
	{
		NSException *exception = [NSException exceptionWithName:NSInternalInconsistencyException reason:
								  [NSString stringWithFormat:@"%@: unexpected method invoked: %@ %@",  [self description], 
								   [anInvocation invocationDescription], [self _recorderDescriptions:NO]] userInfo:nil];
		[exceptions addObject:exception];
		[exception raise];
	}
}


#pragma mark  Helper methods

- (id)getNewRecorder
{
	return [[[OCMockRecorder alloc] initWithSignatureResolver:self] autorelease];
}


- (NSString *)_recorderDescriptions:(BOOL)onlyExpectations
{
	NSMutableString *outputString = [NSMutableString string];
	
	OCMockRecorder *currentObject;
	NSEnumerator *recorderEnumerator = [recorders objectEnumerator];
	while((currentObject = [recorderEnumerator nextObject]) != nil)
	{
		NSString *prefix;
		
		if(onlyExpectations)
		{
			if(![expectations containsObject:currentObject])
				continue;
			prefix = @" ";
		}
		else
		{
			if ([expectations containsObject:currentObject])
				prefix = @"expected: ";
			else
				prefix = @"stubbed: ";
		}
		[outputString appendFormat:@"\n\t%@\t%@", prefix, [currentObject description]];
	}
	
	return outputString;
}


@end
