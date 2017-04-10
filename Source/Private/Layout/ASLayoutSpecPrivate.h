//
//  ASLayoutSpecPrivate.h
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 9/15/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASThread.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASLayoutSpec() {
  ASDN::RecursiveMutex __instanceLock__;
  ASPrimitiveTraitCollection _primitiveTraitCollection;
  ASLayoutElementStyle *_style;
  NSMutableArray *_childrenArray;
}

/**
 * Recursively search the subtree for elements that occur more than once.
 */
- (nullable NSSet<id<ASLayoutElement>> *)findDuplicatedElementsInSubtree;

@end

NS_ASSUME_NONNULL_END
