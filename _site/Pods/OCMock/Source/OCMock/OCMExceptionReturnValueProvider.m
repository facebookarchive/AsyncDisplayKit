//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMExceptionReturnValueProvider.h"


@implementation OCMExceptionReturnValueProvider

- (void)handleInvocation:(NSInvocation *)anInvocation
{
	@throw returnValue;
}

@end
