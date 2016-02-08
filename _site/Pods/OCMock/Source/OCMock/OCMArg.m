//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import <OCMock/OCMArg.h>
#import <OCMock/OCMConstraint.h>
#import "OCMPassByRefSetter.h"

@implementation OCMArg

+ (id)any
{
	return [OCMAnyConstraint constraint];
}

+ (void *)anyPointer
{
	return (void *)0x01234567;
}

+ (id __autoreleasing *)anyObjectRef
{
    return (id *)0x01234567;
}

+ (SEL)anySelector
{
    return NSSelectorFromString(@"aSelectorThatMatchesAnySelector");
}

+ (id)isNil
{
	return [OCMIsNilConstraint constraint];
}

+ (id)isNotNil
{
	return [OCMIsNotNilConstraint constraint];
}

+ (id)isNotEqual:(id)value
{
	OCMIsNotEqualConstraint *constraint = [OCMIsNotEqualConstraint constraint];
	constraint->testValue = value;
	return constraint;
}

+ (id)checkWithSelector:(SEL)selector onObject:(id)anObject
{
	return [OCMConstraint constraintWithSelector:selector onObject:anObject];
}

#if NS_BLOCKS_AVAILABLE

+ (id)checkWithBlock:(BOOL (^)(id))block 
{
	return [[[OCMBlockConstraint alloc] initWithConstraintBlock:block] autorelease];
}

#endif

+ (id *)setTo:(id)value
{
	return (id *)[[[OCMPassByRefSetter alloc] initWithValue:value] autorelease];
}

+ (void *)setToValue:(NSValue *)value
{
	return (id *)[[[OCMPassByRefSetter alloc] initWithValue:value] autorelease];
}

+ (id)resolveSpecialValues:(NSValue *)value
{
	const char *type = [value objCType];
	if(type[0] == '^')
	{
		void *pointer = [value pointerValue];
		if(pointer == (void *)0x01234567)
			return [OCMArg any];
		if((pointer != NULL) && (object_getClass((id)pointer) == [OCMPassByRefSetter class]))
			return (id)pointer;
	}
    else if(type[0] == ':')
    {
        SEL selector;
        [value getValue:&selector];
        if(selector == NSSelectorFromString(@"aSelectorThatMatchesAnySelector"))
            return [OCMArg any];
    }
	return value;
}


@end
