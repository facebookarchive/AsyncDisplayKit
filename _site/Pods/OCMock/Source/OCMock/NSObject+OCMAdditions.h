//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface NSObject(OCMAdditions)

+ (IMP)instanceMethodForwarderForSelector:(SEL)aSelector;

@end