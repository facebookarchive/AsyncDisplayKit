//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMPassByRefSetter.h"


@implementation OCMPassByRefSetter

- (id)initWithValue:(id)aValue
{
	self = [super init];
	value = [aValue retain];
	return self;
}

- (void)dealloc
{
	[value release];
	[super dealloc];
}

- (id)value
{
	return value;
}

@end
