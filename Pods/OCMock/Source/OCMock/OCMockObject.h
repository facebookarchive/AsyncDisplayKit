//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2004-2008 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <Foundation/Foundation.h>

@interface OCMockObject : NSProxy
{
	BOOL			isNice;
	BOOL			expectationOrderMatters;
	NSMutableArray	*recorders;
	NSMutableArray	*expectations;
	NSMutableArray	*rejections;
	NSMutableArray	*exceptions;
}

+ (id)mockForClass:(Class)aClass;
+ (id)mockForProtocol:(Protocol *)aProtocol;
+ (id)partialMockForObject:(NSObject *)anObject;

+ (id)niceMockForClass:(Class)aClass;
+ (id)niceMockForProtocol:(Protocol *)aProtocol;

+ (id)observerMock;

- (id)init;

- (void)setExpectationOrderMatters:(BOOL)flag;

- (id)stub;
- (id)expect;
- (id)reject;

- (void)verify;
- (void)verifyWithDelay:(NSTimeInterval)delay;

- (void)stopMocking;

// internal use only

- (id)getNewRecorder;
- (BOOL)handleInvocation:(NSInvocation *)anInvocation;
- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation;
- (BOOL)handleSelector:(SEL)sel;

@end
