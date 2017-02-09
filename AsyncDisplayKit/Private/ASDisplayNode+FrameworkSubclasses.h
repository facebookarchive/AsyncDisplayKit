//
//  ASDisplayNode+FrameworkPrivate.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

//
// The following methods are ONLY for use by _ASDisplayLayer, _ASDisplayView, and ASDisplayNode.
// These methods must never be called or overridden by other classes.
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASThread.h>

// These are included because most internal subclasses need it.
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASDisplayNode ()
{
  // Protects access to _view, _layer, _pendingViewState, _subnodes, _supernode, and other properties which are accessed from multiple threads.
  @package
  ASDN::RecursiveMutex __instanceLock__;
}
@end

NS_ASSUME_NONNULL_END
