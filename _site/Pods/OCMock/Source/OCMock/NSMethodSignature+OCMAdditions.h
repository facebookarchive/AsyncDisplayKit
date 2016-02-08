//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009, 2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface NSMethodSignature(PrivateAPI)

+ (id)signatureWithObjCTypes:(const char *)types;

@end

@interface NSMethodSignature(OCMAdditions)

- (const char *)methodReturnTypeWithoutQualifiers;
- (BOOL)usesSpecialStructureReturn;
- (NSString *)fullTypeString;
- (const char *)fullObjCTypes;

@end
