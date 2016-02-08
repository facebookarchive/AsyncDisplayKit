//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "NSMethodSignature+OCMAdditions.h"
#import "OCMReturnValueProvider.h"


@implementation OCMReturnValueProvider

- (id)initWithValue:(id)aValue
{
	self = [super init];
	returnValue = [aValue retain];
	return self;
}

- (void)dealloc
{
	[returnValue release];
	[super dealloc];
}

- (void)handleInvocation:(NSInvocation *)anInvocation
{
	const char *returnType = [[anInvocation methodSignature] methodReturnTypeWithoutQualifiers];
	if(strcmp(returnType, @encode(id)) != 0) {
        // if the returnType is a typedef to an object, it has the form ^{OriginClass=#}
        NSString *regexString = @"^\\^\\{(.*)=#.*\\}";
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexString options:0 error:NULL];
        NSString *type = [NSString stringWithCString:returnType encoding:NSASCIIStringEncoding];
        if([regex numberOfMatchesInString:type options:0 range:NSMakeRange(0, type.length)] == 0)
        {
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Expected invocation with object return type. Did you mean to use andReturnValue: instead?" userInfo:nil];
        }
    }
    NSString *sel = NSStringFromSelector([anInvocation selector]);
    if([sel hasPrefix:@"alloc"] || [sel hasPrefix:@"new"] || [sel hasPrefix:@"copy"] || [sel hasPrefix:@"mutableCopy"])
    {
        // methods that "create" an object return it with an extra retain count
        [returnValue retain];
    }
	[anInvocation setReturnValue:&returnValue];
}

@end
