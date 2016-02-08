//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "OCMBoxedReturnValueProvider.h"
#import <objc/runtime.h>

@implementation OCMBoxedReturnValueProvider

- (void)handleInvocation:(NSInvocation *)anInvocation
{
	const char *returnType = [[anInvocation methodSignature] methodReturnType];
	const char *valueType = [(NSValue *)returnValue objCType];
	/* ARM64 uses 'B' for BOOLs in method signatures but 'c' in NSValue; that case should match */
	if((strcmp(returnType, valueType) != 0) && !(returnType[0] == 'B' && valueType[0] == 'c'))
		@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"Return value does not match method signature; signature declares '%s' but value is '%s'.", returnType, valueType] userInfo:nil];
	void *buffer = malloc([[anInvocation methodSignature] methodReturnLength]);
	[returnValue getValue:buffer];
	[anInvocation setReturnValue:buffer];
	free(buffer);
}

@end
