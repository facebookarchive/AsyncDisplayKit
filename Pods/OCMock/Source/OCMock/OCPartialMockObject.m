//---------------------------------------------------------------------------------------
//  $Id$
//  Copyright (c) 2009 by Mulle Kybernetik. See License file for details.
//---------------------------------------------------------------------------------------

#import <objc/runtime.h>
#import "OCPartialMockRecorder.h"
#import "OCPartialMockObject.h"
#import "NSMethodSignature+OCMAdditions.h"
#import "NSObject+OCMAdditions.h"


@interface OCPartialMockObject (Private)
- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation;
@end 

@implementation OCPartialMockObject


#pragma mark  Mock table

static NSMutableDictionary *mockTable;

+ (void)initialize
{
	if(self == [OCPartialMockObject class])
		mockTable = [[NSMutableDictionary alloc] init];
}

+ (void)rememberPartialMock:(OCPartialMockObject *)mock forObject:(id)anObject
{
    @synchronized(mockTable)
    {
        [mockTable setObject:[NSValue valueWithNonretainedObject:mock] forKey:[NSValue valueWithNonretainedObject:anObject]];
    }
}

+ (void)forgetPartialMockForObject:(id)anObject
{
    @synchronized(mockTable)
    {
        [mockTable removeObjectForKey:[NSValue valueWithNonretainedObject:anObject]];
    }
}

+ (OCPartialMockObject *)existingPartialMockForObject:(id)anObject
{
    @synchronized(mockTable)
    {
        OCPartialMockObject *mock = [[mockTable objectForKey:[NSValue valueWithNonretainedObject:anObject]] nonretainedObjectValue];
        if(mock == nil)
            [NSException raise:NSInternalInconsistencyException format:@"No partial mock for object %p", anObject];
        return mock;
    }
}



#pragma mark  Initialisers, description, accessors, etc.

- (id)initWithObject:(NSObject *)anObject
{
	[super initWithClass:[anObject class]];
	realObject = [anObject retain];
	[[self mockObjectClass] rememberPartialMock:self forObject:anObject];
	[self setupSubclassForObject:realObject];
	return self;
}

- (void)dealloc
{
	if(realObject != nil)
		[self stopMocking];
	[super dealloc];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"OCPartialMockObject[%@]", NSStringFromClass(mockedClass)];
}

- (NSObject *)realObject
{
	return realObject;
}

- (void)stopMocking
{
	object_setClass(realObject, [self mockedClass]);
	[realObject release];
	[[self mockObjectClass] forgetPartialMockForObject:realObject];
	realObject = nil;
    
    [super stopMocking];
}


#pragma mark  Subclass management

- (void)setupSubclassForObject:(id)anObject
{
	Class realClass = [anObject class];
	double timestamp = [NSDate timeIntervalSinceReferenceDate];
	const char *className = [[NSString stringWithFormat:@"%@-%p-%f", NSStringFromClass(realClass), anObject, timestamp] UTF8String];
	Class subclass = objc_allocateClassPair(realClass, className, 0);
	objc_registerClassPair(subclass);
	object_setClass(anObject, subclass);

	Method myForwardInvocationMethod = class_getInstanceMethod([self mockObjectClass], @selector(forwardInvocationForRealObject:));
	IMP myForwardInvocationImp = method_getImplementation(myForwardInvocationMethod);
	const char *forwardInvocationTypes = method_getTypeEncoding(myForwardInvocationMethod);
	class_addMethod(subclass, @selector(forwardInvocation:), myForwardInvocationImp, forwardInvocationTypes);


    Method myForwardingTargetForSelectorMethod = class_getInstanceMethod([self mockObjectClass], @selector(forwardingTargetForSelectorForRealObject:));
    IMP myForwardingTargetForSelectorImp = method_getImplementation(myForwardingTargetForSelectorMethod);
    const char *forwardingTargetForSelectorTypes = method_getTypeEncoding(myForwardingTargetForSelectorMethod);

    IMP originalForwardingTargetForSelectorImp = [realClass instanceMethodForSelector:@selector(forwardingTargetForSelector:)];

    class_addMethod(subclass, @selector(forwardingTargetForSelector:), myForwardingTargetForSelectorImp, forwardingTargetForSelectorTypes);
    class_addMethod(subclass, @selector(forwardingTargetForSelector_Original:), originalForwardingTargetForSelectorImp, forwardingTargetForSelectorTypes);
    
    /* We also override the -class method to return the original class */
    Method myObjectClassMethod = class_getInstanceMethod([self mockObjectClass], @selector(classForRealObject));
    const char *objectClassTypes = method_getTypeEncoding(myObjectClassMethod);
    IMP myObjectClassImp = method_getImplementation(myObjectClassMethod);
    IMP originalClassImp = [realClass instanceMethodForSelector:@selector(class)];
    
    class_addMethod(subclass, @selector(class), myObjectClassImp, objectClassTypes);
    class_addMethod(subclass, @selector(class_Original), originalClassImp, objectClassTypes);
}

- (void)setupForwarderForSelector:(SEL)selector
{
	Class subclass = object_getClass([self realObject]);
	Method originalMethod = class_getInstanceMethod([self mockedClass], selector);
	IMP originalImp = method_getImplementation(originalMethod);
    IMP forwarderImp = [[self mockedClass] instanceMethodForwarderForSelector:selector];

	const char *types = method_getTypeEncoding(originalMethod);
	/* Might be NULL if the selector is forwarded to another class */
    // TODO: check the fallback implementation is actually sufficient
    if(types == NULL)
        types = ([[[self mockedClass] instanceMethodSignatureForSelector:selector] fullObjCTypes]);
	class_addMethod(subclass, selector, forwarderImp, types);

	SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
	class_addMethod(subclass, aliasSelector, originalImp, types);
}

- (void)removeForwarderForSelector:(SEL)selector
{
    Class subclass = object_getClass([self realObject]);
    SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector(selector)]);
    Method originalMethod = class_getInstanceMethod([self mockedClass], aliasSelector);
  	IMP originalImp = method_getImplementation(originalMethod);
    class_replaceMethod(subclass, selector, originalImp, method_getTypeEncoding(originalMethod));
}

//  Make the compiler happy in -forwardingTargetForSelectorForRealObject: because it can't find the message…
- (id)forwardingTargetForSelector_Original:(SEL)sel
{
    return nil;
}

- (id)forwardingTargetForSelectorForRealObject:(SEL)sel
{
	// in here "self" is a reference to the real object, not the mock
    OCPartialMockObject *mock = [OCPartialMockObject existingPartialMockForObject:self];
    if ([mock handleSelector:sel])
        return self;

    return [self forwardingTargetForSelector_Original:sel];
}

- (void)forwardInvocationForRealObject:(NSInvocation *)anInvocation
{
	// in here "self" is a reference to the real object, not the mock
	OCPartialMockObject *mock = [OCPartialMockObject existingPartialMockForObject:self];
	if([mock handleInvocation:anInvocation] == NO)
    {
        // if mock doesn't want to handle the invocation, maybe all expects have occurred, we forward to real object
        SEL aliasSelector = NSSelectorFromString([OCMRealMethodAliasPrefix stringByAppendingString:NSStringFromSelector([anInvocation selector])]);
        [anInvocation setSelector:aliasSelector];
        [anInvocation invoke];
    }
}

// Make the compiler happy; we add a method with this name to the real class
- (Class)class_Original
{
    return nil;
}

// Implementation of the -class method; return the Class that was reported with [realObject class] prior to mocking
- (Class)classForRealObject
{
    // "self" is the real object, not the mock
    OCPartialMockObject *mock = [OCPartialMockObject existingPartialMockForObject:self];
    if (mock != nil)
        return [mock mockedClass];

    return [self class_Original];
}

#pragma mark  Overrides

- (id)getNewRecorder
{
	return [[[OCPartialMockRecorder alloc] initWithSignatureResolver:self] autorelease];
}

- (void)handleUnRecordedInvocation:(NSInvocation *)anInvocation
{
	[anInvocation invokeWithTarget:realObject];
}


@end
