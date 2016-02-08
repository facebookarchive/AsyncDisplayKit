//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2010 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMRealObjectForwarder : NSObject 
{
}

- (void)handleInvocation:(NSInvocation *)anInvocation;

@end
