//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import "NSMethodSignature+OCMAdditions.h"
#import <objc/runtime.h>


@implementation NSMethodSignature(OCMAdditions)

- (const char *)methodReturnTypeWithoutQualifiers
{
	const char *returnType = [self methodReturnType];
	while(strchr("rnNoORV", returnType[0]) != NULL)
		returnType += 1;
	return returnType;
}

- (BOOL)usesSpecialStructureReturn
{
    const char *types = [self methodReturnTypeWithoutQualifiers];

    if((types == NULL) || (types[0] != '{'))
        return NO;

    /* In some cases structures are returned by ref. The rules are complex and depend on the
       architecture, see:

       http://sealiesoftware.com/blog/archive/2008/10/30/objc_explain_objc_msgSend_stret.html
       http://developer.apple.com/library/mac/#documentation/DeveloperTools/Conceptual/LowLevelABI/000-Introduction/introduction.html
       https://github.com/atgreen/libffi/blob/master/src/x86/ffi64.c
       http://www.uclibc.org/docs/psABI-x86_64.pdf
       http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf

       NSMethodSignature knows the details but has no API to return it, though it is in
       the debugDescription. Horribly kludgy.
    */
    NSRange range = [[self debugDescription] rangeOfString:@"is special struct return? YES"];
    return range.length > 0;
}

- (NSString *)fullTypeString
{
    NSMutableString *typeString = [NSMutableString string];
    [typeString appendFormat:@"%s", [self methodReturnType]];
    for (NSUInteger i=0; i<[self numberOfArguments]; i++)
        [typeString appendFormat:@"%s", [self getArgumentTypeAtIndex:i]];
    return typeString;
}

- (const char *)fullObjCTypes
{
    return [[self fullTypeString] UTF8String];
}

@end
