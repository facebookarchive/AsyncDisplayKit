//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMPassByRefSetter : NSObject 
{
	id value;
}

- (id)initWithValue:(id)value;

- (id)value;

@end
