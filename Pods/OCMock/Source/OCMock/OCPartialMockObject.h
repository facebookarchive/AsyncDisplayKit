//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCClassMockObject.h"

@interface OCPartialMockObject : OCClassMockObject 
{
	NSObject	*realObject;
}

- (id)initWithObject:(NSObject *)anObject;

- (NSObject *)realObject;

- (void)stopMocking;

- (void)setupSubclassForObject:(id)anObject;
- (void)setupForwarderForSelector:(SEL)selector;

@end
