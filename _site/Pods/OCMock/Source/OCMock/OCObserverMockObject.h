//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCObserverMockObject : NSObject 
{
	BOOL			expectationOrderMatters;
	NSMutableArray	*recorders;
}

- (void)setExpectationOrderMatters:(BOOL)flag;

- (id)expect;

- (void)verify;

- (void)handleNotification:(NSNotification *)aNotification;

@end
