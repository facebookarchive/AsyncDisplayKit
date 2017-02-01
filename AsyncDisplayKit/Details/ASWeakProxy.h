//
//  ASWeakProxy.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/12/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

AS_SUBCLASSING_RESTRICTED
@interface ASWeakProxy : NSProxy

/**
 * @return target The target which will be forwarded all messages sent to the weak proxy.
 */
@property (nonatomic, weak, readonly) id target;

/**
 * An object which forwards messages to a target which it weakly references
 *
 * @discussion This class is useful for breaking retain cycles. You can pass this in place
 * of the target to something which creates a strong reference. All messages sent to the
 * proxy will be passed onto the target.
 *
 * @return an instance of ASWeakProxy
 */
+ (instancetype)weakProxyWithTarget:(id)target;

@end
