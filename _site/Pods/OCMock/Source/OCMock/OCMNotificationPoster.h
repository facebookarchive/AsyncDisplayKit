//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMNotificationPoster : NSObject 
{
	NSNotification *notification;
}

- (id)initWithNotification:(id)aNotification;

- (void)handleInvocation:(NSInvocation *)anInvocation;

@end
