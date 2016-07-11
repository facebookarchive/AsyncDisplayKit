//
//  ASDelegateProxy.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDelegateProxy.h"
#import "ASTableView.h"
#import "ASCollectionView.h"
#import "ASAssert.h"

@implementation ASTableViewProxy

- (BOOL)interceptsSelector:(SEL)selector
{
  return (
          // handled by ASTableView node<->cell machinery
          selector == @selector(tableView:cellForRowAtIndexPath:) ||
          selector == @selector(tableView:heightForRowAtIndexPath:) ||
          
          // handled by ASRangeController
          selector == @selector(numberOfSectionsInTableView:) ||
          selector == @selector(tableView:numberOfRowsInSection:) ||
          
          // used for ASCellNode visibility
          selector == @selector(scrollViewDidScroll:) ||

          // used for ASCellNode user interaction
          selector == @selector(scrollViewWillBeginDragging:) ||
          selector == @selector(scrollViewDidEndDragging:willDecelerate:) ||
          
          // used for ASRangeController visibility updates
          selector == @selector(tableView:willDisplayCell:forRowAtIndexPath:) ||
          selector == @selector(tableView:didEndDisplayingCell:forRowAtIndexPath:) ||
          
          // used for batch fetching API
          selector == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)
          );
}

@end

@implementation ASCollectionViewProxy

- (BOOL)interceptsSelector:(SEL)selector
{
  return (
          // handled by ASCollectionView node<->cell machinery
          selector == @selector(collectionView:cellForItemAtIndexPath:) ||
          selector == @selector(collectionView:layout:sizeForItemAtIndexPath:) ||
          selector == @selector(collectionView:viewForSupplementaryElementOfKind:atIndexPath:) ||
          
          // handled by ASRangeController
          selector == @selector(numberOfSectionsInCollectionView:) ||
          selector == @selector(collectionView:numberOfItemsInSection:) ||
          
          // used for ASRangeController visibility updates
          selector == @selector(collectionView:willDisplayCell:forItemAtIndexPath:) ||
          selector == @selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:) ||
          
          // used for batch fetching API
          selector == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:) ||
          
          // used for ASCellNode visibility
          selector == @selector(scrollViewDidScroll:) ||

          // used for ASCellNode user interaction
          selector == @selector(scrollViewWillBeginDragging:) ||
          selector == @selector(scrollViewDidEndDragging:willDecelerate:) ||
          
          // intercepted due to not being supported by ASCollectionView (prevent bugs caused by usage)
          selector == @selector(collectionView:canMoveItemAtIndexPath:) ||
          selector == @selector(collectionView:moveItemAtIndexPath:toIndexPath:) ||
          selector == @selector(collectionView:willDisplaySupplementaryView:forElementKind:atIndexPath:) ||
          selector == @selector(collectionView:didEndDisplayingSupplementaryView:forElementOfKind:atIndexPath:)
          );
}

@end

@implementation ASPagerNodeProxy

- (BOOL)interceptsSelector:(SEL)selector
{
  return (
          // handled by ASPagerDataSource node<->cell machinery
          selector == @selector(collectionView:nodeForItemAtIndexPath:) ||
          selector == @selector(collectionView:nodeBlockForItemAtIndexPath:) ||
          selector == @selector(collectionView:numberOfItemsInSection:) ||
          selector == @selector(collectionView:constrainedSizeForNodeAtIndexPath:) ||
          selector == @selector(scrollViewWillEndDragging:withVelocity:targetContentOffset:)
          );
}

@end

@implementation ASDelegateProxy {
  id <ASDelegateProxyInterceptor> __weak _interceptor;
  id <NSObject> __weak _target;
}

- (instancetype)initWithTarget:(id <NSObject>)target interceptor:(id <ASDelegateProxyInterceptor>)interceptor
{
  // -[NSProxy init] is undefined
  if (!self) {
    return nil;
  }
  
  ASDisplayNodeAssert(interceptor, @"interceptor must not be nil");
  
  _target = target ? : [NSNull null];
  _interceptor = interceptor;
  
  return self;
}

- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
  if (_target) {
    return [_target conformsToProtocol:aProtocol];
  } else {
    return [super conformsToProtocol:aProtocol];
  }
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
  if ([self interceptsSelector:aSelector]) {
    return [_interceptor respondsToSelector:aSelector];
  } else {
    // Also return NO if _target has become nil due to zeroing weak reference (or placeholder initialization).
    return [_target respondsToSelector:aSelector];
  }
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
  if ([self interceptsSelector:aSelector]) {
    return _interceptor;
  } else {
    if (_target) {
      return [_target respondsToSelector:aSelector] ? _target : nil;
    } else {
      // The _interceptor needs to be nilled out in this scenario. For that a strong reference needs to be created
      // to be able to nil out the _interceptor but still let it know that the proxy target has deallocated
      // We have to hold a strong reference to the interceptor as we have to nil it out and call the proxyTargetHasDeallocated
      // The reason that the interceptor needs to be nilled out is that there maybe a change of a infinite loop, for example
      // if a method will be called in the proxyTargetHasDeallocated: that again would trigger a whole new forwarding cycle
      id <ASDelegateProxyInterceptor> interceptor = _interceptor;
      _interceptor = nil;
      [interceptor proxyTargetHasDeallocated:self];
      
      return nil;
    }
  }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
  // Check for a compiled definition for the selector
  NSMethodSignature *methodSignature = nil;
  if ([self interceptsSelector:aSelector]) {
    methodSignature = [[_interceptor class] instanceMethodSignatureForSelector:aSelector];
  } else {
    methodSignature = [[_target class] instanceMethodSignatureForSelector:aSelector];
  }
  
  // Unfortunately, in order to get this object to work properly, the use of a method which creates an NSMethodSignature
  // from a C string. -methodSignatureForSelector is called when a compiled definition for the selector cannot be found.
  // This is the place where we have to create our own dud NSMethodSignature. This is necessary because if this method
  // returns nil, a selector not found exception is raised. The string argument to -signatureWithObjCTypes: outlines
  // the return type and arguments to the message. To return a dud NSMethodSignature, pretty much any signature will
  // suffice. Since the -forwardInvocation call will do nothing if the delegate does not respond to the selector,
  // the dud NSMethodSignature simply gets us around the exception.
  return methodSignature ?: [NSMethodSignature signatureWithObjCTypes:"@^v^c"];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    // If we are down here this means _interceptor and _target where nil. Just don't do anything to prevent a crash
}

- (BOOL)interceptsSelector:(SEL)selector
{
  ASDisplayNodeAssert(NO, @"This method must be overridden by subclasses.");
  return NO;
}

@end
