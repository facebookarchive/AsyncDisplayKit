/* Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

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
          // handled by ASPagerNodeDataSource node<->cell machinery
          selector == @selector(collectionView:nodeForItemAtIndexPath:) ||
          selector == @selector(collectionView:nodeBlockForItemAtIndexPath:) ||
          selector == @selector(collectionView:numberOfItemsInSection:) ||
          selector == @selector(collectionView:constrainedSizeForNodeAtIndexPath:)
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
      [_interceptor proxyTargetHasDeallocated:self];
      return nil;
    }
  }
}

- (BOOL)interceptsSelector:(SEL)selector
{
  ASDisplayNodeAssert(NO, @"This method must be overridden by subclasses.");
  return NO;
}

@end
