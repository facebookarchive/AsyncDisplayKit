//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMReturnValueProvider : NSObject 
{
	id	returnValue;
}

- (id)initWithValue:(id)aValue;

- (void)handleInvocation:(NSInvocation *)anInvocation;

@end
