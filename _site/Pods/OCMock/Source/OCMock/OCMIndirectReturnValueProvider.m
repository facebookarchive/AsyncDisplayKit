//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "NSMethodSignature+OCMAdditions.h"
#import "OCMIndirectReturnValueProvider.h"


@implementation OCMIndirectReturnValueProvider

- (id)initWithProvider:(id)aProvider andSelector:(SEL)aSelector
{
	self = [super init];
	provider = [aProvider retain];
	selector = aSelector;
	return self;
}

- (void)dealloc
{
	[provider release];
	[super dealloc];
}

- (void)handleInvocation:(NSInvocation *)anInvocation
{
	[anInvocation setTarget:provider];
	[anInvocation setSelector:selector];
	[anInvocation invoke];
}

@end
