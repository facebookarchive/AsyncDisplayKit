//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMIndirectReturnValueProvider : NSObject 
{
	id	provider;
	SEL	selector;
}

- (id)initWithProvider:(id)aProvider andSelector:(SEL)aSelector;

- (void)handleInvocation:(NSInvocation *)anInvocation;

@end
