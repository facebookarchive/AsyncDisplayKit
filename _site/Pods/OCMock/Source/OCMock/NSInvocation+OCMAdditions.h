//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2006-2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface NSInvocation(OCMAdditions)

- (id)getArgumentAtIndexAsObject:(int)argIndex;

- (NSString *)invocationDescription;

- (NSString *)argumentDescriptionAtIndex:(int)argIndex;

- (NSString *)objectDescriptionAtIndex:(int)anInt;
- (NSString *)charDescriptionAtIndex:(int)anInt;
- (NSString *)unsignedCharDescriptionAtIndex:(int)anInt;
- (NSString *)intDescriptionAtIndex:(int)anInt;
- (NSString *)unsignedIntDescriptionAtIndex:(int)anInt;
- (NSString *)shortDescriptionAtIndex:(int)anInt;
- (NSString *)unsignedShortDescriptionAtIndex:(int)anInt;
- (NSString *)longDescriptionAtIndex:(int)anInt;
- (NSString *)unsignedLongDescriptionAtIndex:(int)anInt;
- (NSString *)longLongDescriptionAtIndex:(int)anInt;
- (NSString *)unsignedLongLongDescriptionAtIndex:(int)anInt;
- (NSString *)doubleDescriptionAtIndex:(int)anInt;
- (NSString *)floatDescriptionAtIndex:(int)anInt;
- (NSString *)structDescriptionAtIndex:(int)anInt;
- (NSString *)pointerDescriptionAtIndex:(int)anInt;
- (NSString *)cStringDescriptionAtIndex:(int)anInt;
- (NSString *)selectorDescriptionAtIndex:(int)anInt;

@end
