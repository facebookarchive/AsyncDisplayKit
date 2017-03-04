//
//  ASDelegateProxy.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@class ASDelegateProxy;
@protocol ASDelegateProxyInterceptor <NSObject>
@required
// Called if the target object is discovered to be nil if it had been non-nil at init time.
// This happens if the object is deallocated, because the proxy must maintain a weak reference to avoid cycles.
// Though the target object may become nil, the interceptor must not; it is assumed the interceptor owns the proxy.
- (void)proxyTargetHasDeallocated:(ASDelegateProxy *)proxy;
@end

/**
 * Stand-in for delegates like UITableView or UICollectionView's delegate / dataSource.
 * Any selectors flagged by "interceptsSelector" are routed to the interceptor object and are not delivered to the target.
 * Everything else leaves AsyncDisplayKit safely and arrives at the original target object.
 */

@interface ASDelegateProxy : NSProxy

- (instancetype)initWithTarget:(id <NSObject>)target interceptor:(id <ASDelegateProxyInterceptor>)interceptor;

// This method must be overridden by a subclass.
- (BOOL)interceptsSelector:(SEL)selector;

@end

/**
 * ASTableView intercepts and/or overrides a few of UITableView's critical data source and delegate methods.
 *
 * Any selector included in this function *MUST* be implemented by ASTableView.
 */

@interface ASTableViewProxy : ASDelegateProxy
@end

/**
 * ASCollectionView intercepts and/or overrides a few of UICollectionView's critical data source and delegate methods.
 *
 * Any selector included in this function *MUST* be implemented by ASCollectionView.
 */

@interface ASCollectionViewProxy : ASDelegateProxy
@end

@interface ASPagerNodeProxy : ASDelegateProxy
@end

