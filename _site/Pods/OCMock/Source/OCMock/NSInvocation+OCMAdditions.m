//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2006-2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "NSInvocation+OCMAdditions.h"


@implementation NSInvocation(OCMAdditions)

- (id)getArgumentAtIndexAsObject:(int)argIndex
{
	const char* argType;
	
	argType = [[self methodSignature] getArgumentTypeAtIndex:argIndex];
	while(strchr("rnNoORV", argType[0]) != NULL)
		argType += 1;
	
	if((strlen(argType) > 1) && (strchr("{^", argType[0]) == NULL) && (strcmp("@?", argType) != 0))
		[NSException raise:NSInvalidArgumentException format:@"Cannot handle argument type '%s'.", argType];
	
	switch (argType[0]) 
	{
		case '#':
		case '@': 
		{
			id value;
			[self getArgument:&value atIndex:argIndex];
			return value;
		}
		case ':':
 		{
 			SEL s = (SEL)0;
 			[self getArgument:&s atIndex:argIndex];
            return [NSValue valueWithBytes:&s objCType:":"];
 		}
		case 'i': 
		{
			int value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithInt:value];
		}	
		case 's':
		{
			short value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithShort:value];
		}	
		case 'l':
		{
			long value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithLong:value];
		}	
		case 'q':
		{
			long long value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithLongLong:value];
		}	
		case 'c':
		{
			char value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithChar:value];
		}	
		case 'C':
		{
			unsigned char value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithUnsignedChar:value];
		}	
		case 'I':
		{
			unsigned int value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithUnsignedInt:value];
		}	
		case 'S':
		{
			unsigned short value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithUnsignedShort:value];
		}	
		case 'L':
		{
			unsigned long value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithUnsignedLong:value];
		}	
		case 'Q':
		{
			unsigned long long value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithUnsignedLongLong:value];
		}	
		case 'f':
		{
			float value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithFloat:value];
		}	
		case 'd':
		{
			double value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithDouble:value];
		}	
		case 'D':
		{
			long double value;
			[self getArgument:&value atIndex:argIndex];
			return [NSValue valueWithBytes:&value objCType:@encode(typeof(value))];
		}
		case 'B':
		{
			bool value;
			[self getArgument:&value atIndex:argIndex];
			return [NSNumber numberWithBool:value];
		}
		case '^':
        {
            void *value = NULL;
            [self getArgument:&value atIndex:argIndex];
            return [NSValue valueWithPointer:value];
        }
		case '{': // structure
		{
			NSUInteger argSize;
			NSGetSizeAndAlignment([[self methodSignature] getArgumentTypeAtIndex:argIndex], &argSize, NULL);
			if(argSize == 0) // TODO: Can this happen? Is frameLength a good choice in that case?
                argSize = [[self methodSignature] frameLength];
			NSMutableData *argumentData = [[[NSMutableData alloc] initWithLength:argSize] autorelease];
			[self getArgument:[argumentData mutableBytes] atIndex:argIndex];
			return [NSValue valueWithBytes:[argumentData bytes] objCType:argType];
		}       
			
	}
	[NSException raise:NSInvalidArgumentException format:@"Argument type '%s' not supported", argType];
	return nil;
}

- (NSString *)invocationDescription
{
	NSMethodSignature *methodSignature = [self methodSignature];
	NSUInteger numberOfArgs = [methodSignature numberOfArguments];
	
	if (numberOfArgs == 2)
		return NSStringFromSelector([self selector]);
	
	NSArray *selectorParts = [NSStringFromSelector([self selector]) componentsSeparatedByString:@":"];
	NSMutableString *description = [[NSMutableString alloc] init];
	unsigned int i;
	for(i = 2; i < numberOfArgs; i++)
	{
		[description appendFormat:@"%@%@:", (i > 2 ? @" " : @""), [selectorParts objectAtIndex:(i - 2)]];
		[description appendString:[self argumentDescriptionAtIndex:i]];
	}
	
	return [description autorelease];
}

- (NSString *)argumentDescriptionAtIndex:(int)argIndex
{
	const char *argType = [[self methodSignature] getArgumentTypeAtIndex:argIndex];
	if(strchr("rnNoORV", argType[0]) != NULL)
		argType += 1;

	switch(*argType)
	{
		case '@':	return [self objectDescriptionAtIndex:argIndex];
		case 'B':	return [self boolDescriptionAtIndex:argIndex];
		case 'c':	return [self charDescriptionAtIndex:argIndex];
		case 'C':	return [self unsignedCharDescriptionAtIndex:argIndex];
		case 'i':	return [self intDescriptionAtIndex:argIndex];
		case 'I':	return [self unsignedIntDescriptionAtIndex:argIndex];
		case 's':	return [self shortDescriptionAtIndex:argIndex];
		case 'S':	return [self unsignedShortDescriptionAtIndex:argIndex];
		case 'l':	return [self longDescriptionAtIndex:argIndex];
		case 'L':	return [self unsignedLongDescriptionAtIndex:argIndex];
		case 'q':	return [self longLongDescriptionAtIndex:argIndex];
		case 'Q':	return [self unsignedLongLongDescriptionAtIndex:argIndex];
		case 'd':	return [self doubleDescriptionAtIndex:argIndex];
		case 'f':	return [self floatDescriptionAtIndex:argIndex];
		case 'D':	return [self longDoubleDescriptionAtIndex:argIndex];
		case '{':	return [self structDescriptionAtIndex:argIndex];
		case '^':	return [self pointerDescriptionAtIndex:argIndex];
		case '*':	return [self cStringDescriptionAtIndex:argIndex];
		case ':':	return [self selectorDescriptionAtIndex:argIndex];
		default:	return [@"<??" stringByAppendingString:@">"];  // avoid confusion with trigraphs...
	}
	
}


- (NSString *)objectDescriptionAtIndex:(int)anInt
{
	id object;
	
	[self getArgument:&object atIndex:anInt];
	if (object == nil)
		return @"nil";
	else if(![object isProxy] && [object isKindOfClass:[NSString class]])
		return [NSString stringWithFormat:@"@\"%@\"", [object description]];
	else
		// The description cannot be nil, if it is then replace it
		return [object description] ?: @"<nil description>";
}

- (NSString *)boolDescriptionAtIndex:(int)anInt
{
	bool value;
	[self getArgument:&value atIndex:anInt];
	return value? @"YES" : @"NO";
}

- (NSString *)charDescriptionAtIndex:(int)anInt
{
	unsigned char buffer[128];
	memset(buffer, 0x0, 128);
	
	[self getArgument:&buffer atIndex:anInt];
	
	// If there's only one character in the buffer, and it's 0 or 1, then we have a BOOL
	if (buffer[1] == '\0' && (buffer[0] == 0 || buffer[0] == 1))
		return (buffer[0] == 1 ? @"YES" : @"NO");
	else
		return [NSString stringWithFormat:@"'%c'", *buffer];
}

- (NSString *)unsignedCharDescriptionAtIndex:(int)anInt
{
	unsigned char buffer[128];
	memset(buffer, 0x0, 128);
	
	[self getArgument:&buffer atIndex:anInt];
	return [NSString stringWithFormat:@"'%c'", *buffer];
}

- (NSString *)intDescriptionAtIndex:(int)anInt
{
	int intValue;
	
	[self getArgument:&intValue atIndex:anInt];
	return [NSString stringWithFormat:@"%d", intValue];
}

- (NSString *)unsignedIntDescriptionAtIndex:(int)anInt
{
	unsigned int intValue;
	
	[self getArgument:&intValue atIndex:anInt];
	return [NSString stringWithFormat:@"%d", intValue];
}

- (NSString *)shortDescriptionAtIndex:(int)anInt
{
	short shortValue;
	
	[self getArgument:&shortValue atIndex:anInt];
	return [NSString stringWithFormat:@"%hi", shortValue];
}

- (NSString *)unsignedShortDescriptionAtIndex:(int)anInt
{
	unsigned short shortValue;
	
	[self getArgument:&shortValue atIndex:anInt];
	return [NSString stringWithFormat:@"%hu", shortValue];
}

- (NSString *)longDescriptionAtIndex:(int)anInt
{
	long longValue;
	
	[self getArgument:&longValue atIndex:anInt];
	return [NSString stringWithFormat:@"%ld", longValue];
}

- (NSString *)unsignedLongDescriptionAtIndex:(int)anInt
{
	unsigned long longValue;
	
	[self getArgument:&longValue atIndex:anInt];
	return [NSString stringWithFormat:@"%lu", longValue];
}

- (NSString *)longLongDescriptionAtIndex:(int)anInt
{
	long long longLongValue;
	
	[self getArgument:&longLongValue atIndex:anInt];
	return [NSString stringWithFormat:@"%qi", longLongValue];
}

- (NSString *)unsignedLongLongDescriptionAtIndex:(int)anInt
{
	unsigned long long longLongValue;
	
	[self getArgument:&longLongValue atIndex:anInt];
	return [NSString stringWithFormat:@"%qu", longLongValue];
}

- (NSString *)doubleDescriptionAtIndex:(int)anInt
{
	double doubleValue;
	
	[self getArgument:&doubleValue atIndex:anInt];
	return [NSString stringWithFormat:@"%f", doubleValue];
}

- (NSString *)floatDescriptionAtIndex:(int)anInt
{
	float floatValue;
	
	[self getArgument:&floatValue atIndex:anInt];
	return [NSString stringWithFormat:@"%f", floatValue];
}

- (NSString *)longDoubleDescriptionAtIndex:(int)anInt
{
	long double longDoubleValue;
	
	[self getArgument:&longDoubleValue atIndex:anInt];
	return [NSString stringWithFormat:@"%Lf", longDoubleValue];
}

- (NSString *)structDescriptionAtIndex:(int)anInt
{
    return [NSString stringWithFormat:@"(%@)", [[self getArgumentAtIndexAsObject:anInt] description]];
}

- (NSString *)pointerDescriptionAtIndex:(int)anInt
{
	void *buffer;
	
	[self getArgument:&buffer atIndex:anInt];
	return [NSString stringWithFormat:@"%p", buffer];
}

- (NSString *)cStringDescriptionAtIndex:(int)anInt
{
	char buffer[104];
	char *cStringPtr;
	
	[self getArgument:&cStringPtr atIndex:anInt];
	strncpy(buffer, cStringPtr, 100);
    strcpy(buffer + 100, "...");
	return [NSString stringWithFormat:@"\"%s\"", buffer];
}

- (NSString *)selectorDescriptionAtIndex:(int)anInt
{
	SEL selectorValue;
	
	[self getArgument:&selectorValue atIndex:anInt];
	return [NSString stringWithFormat:@"@selector(%@)", NSStringFromSelector(selectorValue)];
}

@end
