//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009-2010 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCPartialMockObject.h"
#import "OCMRealObjectForwarder.h"
#import "OCPartialMockRecorder.h"


@implementation OCPartialMockRecorder

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[super forwardInvocation:anInvocation];
	// not as clean as I'd wish...
	[(OCPartialMockObject *)signatureResolver setupForwarderForSelector:[anInvocation selector]];
}

@end
