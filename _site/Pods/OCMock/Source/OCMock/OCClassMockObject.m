//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2005-2013 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import "OCClassMockObject.h"
#import "NSMethodSignature+OCMAdditions.h"
#import "NSObject+OCMAdditions.h"


NSString *OCMRealMethodAliasPrefix = @"ocmock_replaced_";


@implementation OCClassMockObject

#pragma mark  Mock table

static NSMutableDictionary *mockTable;

+ (void)initialize
{
	if(self == [OCClassMockObject class])
		mockTable = [[NSMutableDictionary alloc] init];
}

+ (void)rememberMock:(OCClassMockObject *)mock forClass:(Class)aClass
{
    @synchronized(mockTable)
    {
        [mockTable setObject:[NSValue valueWithNonretainedObject:mock] forKey:[NSValue valueWithNonretainedObject:aClass]];
    }
}

+ (void)forgetMockForClass:(Class)aClass
{
    @synchronized(mockTable)
    {
        [mockTable removeObjectForKey:[NSValue valueWithNonretainedObject:aClass]];
    }
}

+ (OCClassMockObject *)existingMockForClass:(Class)aClass
{
    @synchronized(mockTable)
    {
        OCClassMockObject *mock = nil;
        while((mock == nil) && (aClass != nil))
        {
            mock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:aClass]] nonretainedObjectValue];
            aClass = class_getSuperclass(aClass);
        }
        if(mock == nil)
            [NSException raise:NSInternalInconsistencyException format:@"No mock for class %@", NSStringFromClass(aClass)];
        return mock;
    }
}

#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithClass:(Class)aClass
{
	[super init];
	mockedClass = aClass;
	return self;
}

- (void)dealloc
{
	if(replacedClassMethods != nil)
    {
		[self stopMocking];
        [[self mockObjectClass] forgetMockForClass:mockedClass];
        [replacedClassMethods release];
    }
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCMockObject[%@]", NSStringFromClass(mockedClass)];
}

- (Class)mockedClass
{
	return mockedClass;
}


#pragma mark  Class method mocking

- (void)setupClassForClassMethodMocking
{
    if(replacedClassMethods != nil)
        return;

    replacedClassMethods = [[NSMutableDictionary alloc] init];
    [[self mockObjectClass] rememberMock:self forClass:mockedClass];

    Method method = class_getClassMethod(mockedClass, @selector(forwardInvocation:));
    IMP originalIMP = method_getImplementation(method);
    [replacedClassMethods setObject:[NSValue valueWithPointer:originalIMP] forKey:NSStringFromSelector(@selector(forwardInvocation:))];

    Method myForwardMethod = class_getInstanceMethod([self mockObjectClass], @selector(forwardInvocationForClassObject:));
   	IMP myForwardIMP = method_getImplementation(myForwardMethod);
    Class metaClass = object_getClass(mockedClass);
	class_replaceMethod(metaClass, @selector(forwardInvocation:), myForwardIMP, method_getTypeEncoding(myForwardMethod));
}

- (void)setupForwarderForClassMethodSelector:(SEL)selector
{
    if([replacedClassMethods objectForKey:NSStringFromSelector(selector)] != nil)
        return;

    // We're using class_replaceMethod and not method_setImplementation to make sure
    // the stub is definitely added to the mocked class, and not a superclass. However,
    // we still get the originalIMP from the method in case it was actually implemented
    // in a superclass.
    Method method = class_getClassMethod(mockedClass, selector);
    IMP originalIMP = method_getImplementation(method);
    [replacedClassMethods setObject:[NSValue valueWithPointer:originalIMP] forKey:NSStringFromSelector(selector)];

    Class metaClass = object_getClass(mockedClass);
    IMP forwarderIMP = [metaClass instanceMethodForwarderForSelector:selector];
    class_replaceMethod(metaClass, method_getName(method), forwarderIMP, method_getTypeEncoding(method));
    
    SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
    class_addMethod(metaClass, aliasSelector, originalIMP, method_getTypeEncoding(method));
}

- (void)removeForwarderForClassMethodSelector:(SEL)selector
{
    IMP originalIMP = [[replacedClassMethods objectForKey:NSStringFromSelector(selector)] pointerValue];
	if(originalIMP == NULL)
    {
        [NSException raise:NSInternalInconsistencyException format:@"%@: Trying to remove stub for class method %@, but no previous implementation available.",
            [self description], NSStringFromSelector(selector)];
	}
    Method method = class_getClassMethod(mockedClass, selector);
    method_setImplementation(method, originalIMP);
}

- (void)forwardInvocationForClassObject:(NSInvocation *)anInvocation
{
	// in here "self" is a reference to the real class, not the mock
	OCClassMockObject *mock = [OCClassMockObject existingMockForClass:(Class)self];
	if([mock handleInvocation:anInvocation] == NO)
    {
        // if mock doesn't want to handle the invocation, maybe all expects have occurred, we remove the forwarder and try again
        [mock removeForwarderForClassMethodSelector:[anInvocation selector]];
        [anInvocation invoke];
    }
}

- (void)stopMocking
{
	for(NSString *replacedMethod in replacedClassMethods)
        [self removeForwarderForClassMethodSelector:NSSelectorFromString(replacedMethod)];
}


#pragma mark  Proxy API

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [mockedClass instanceMethodSignatureForSelector:aSelector];
}

- (Class)mockObjectClass
{
    return [super class];
}

- (Class)class
{
    return mockedClass;
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [mockedClass instancesRespondToSelector:selector];
}

- (BOOL)isKindOfClass:(Class)aClass
{
    return [mockedClass isSubclassOfClass:aClass];
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
    return class_conformsToProtocol(mockedClass, aProtocol);
}

@end


#pragma mark  -

/**
 taken from:
 `class-dump -f isNS /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator7.0.sdk/System/Library/Frameworks/CoreFoundation.framework`
 
 @interface NSObject (__NSIsKinds)
 - (_Bool)isNSValue__;
 - (_Bool)isNSTimeZone__;
 - (_Bool)isNSString__;
 - (_Bool)isNSSet__;
 - (_Bool)isNSOrderedSet__;
 - (_Bool)isNSNumber__;
 - (_Bool)isNSDictionary__;
 - (_Bool)isNSDate__;
 - (_Bool)isNSData__;
 - (_Bool)isNSArray__;
 */

@implementation OCClassMockObject(NSIsKindsImplementation)

- (BOOL)isNSValue__
{
    return [mockedClass isKindOfClass:[NSValue class]];
}

- (BOOL)isNSTimeZone__
{
    return [mockedClass isKindOfClass:[NSTimeZone class]];
}

- (BOOL)isNSSet__
{
    return [mockedClass isKindOfClass:[NSSet class]];
}

- (BOOL)isNSOrderedSet__
{
    return [mockedClass isKindOfClass:[NSOrderedSet class]];
}

- (BOOL)isNSNumber__
{
    return [mockedClass isKindOfClass:[NSNumber class]];
}

- (BOOL)isNSDate__
{
    return [mockedClass isKindOfClass:[NSDate class]];
}

- (BOOL)isNSString__
{
    return [mockedClass isKindOfClass:[NSString class]];
}

- (BOOL)isNSDictionary__
{
    return [mockedClass isKindOfClass:[NSDictionary class]];
}

- (BOOL)isNSData__
{
    return [mockedClass isKindOfClass:[NSData class]];
}

- (BOOL)isNSArray__
{
    return [mockedClass isKindOfClass:[NSArray class]];
}

@end
