//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCObserverMockObject.h"
#import "OCMObserverRecorder.h"


@implementation OCObserverMockObject

#pragma mark  Initialisers, description, accessors, etc.

- (id)init
{
	self = [super init];
	recorders = [[NSMutableArray alloc] init];
	return self;
}

- (void)dealloc
{
	[recorders release];
	[super dealloc];
}

- (NSString *)description
{
	return @"OCMockObserver";
}

- (void)setExpectationOrderMatters:(BOOL)flag
{
    expectationOrderMatters = flag;
}


#pragma mark  Public API

- (id)expect
{
	OCMObserverRecorder *recorder = [[[OCMObserverRecorder alloc] init] autorelease];
	[recorders addObject:recorder];
	return recorder;
}

- (void)verify
{
	if([recorders count] == 1)
	{
		[NSException raise:NSInternalInconsistencyException format:@"%@: expected notification was not observed: %@", 
		 [self description], [[recorders lastObject] description]];
	}
	if([recorders count] > 0)
	{
		[NSException raise:NSInternalInconsistencyException format:@"%@ : %@ expected notifications were not observed.", 
		 [self description], @([recorders count])];
	}
}



#pragma mark  Receiving notifications

- (void)handleNotification:(NSNotification *)aNotification
{
	NSUInteger i, limit;
	
	limit = expectationOrderMatters ? 1 : [recorders count];
	for(i = 0; i < limit; i++)
	{
		if([[recorders objectAtIndex:i] matchesNotification:aNotification])
		{
			[recorders removeObjectAtIndex:i];
			return;
		}
	}
	[NSException raise:NSInternalInconsistencyException format:@"%@: unexpected notification observed: %@", [self description], 
	  [aNotification description]];
}


@end
