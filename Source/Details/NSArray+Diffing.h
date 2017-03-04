//
//  NSArray+Diffing.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@interface NSArray (Diffing)

/**
 * @abstract Compares two arrays, providing the insertion and deletion indexes needed to transform into the target array.
 * @discussion This compares the equality of each object with `isEqual:`.
 * This diffing algorithm uses a bottom-up memoized longest common subsequence solution to identify differences.
 * It runs in O(mn) complexity.
 */
- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions;

/**
 * @abstract Compares two arrays, providing the insertion and deletion indexes needed to transform into the target array.
 * @discussion The `compareBlock` is used to identify the equality of the objects within the arrays.
 * This diffing algorithm uses a bottom-up memoized longest common subsequence solution to identify differences.
 * It runs in O(mn) complexity.
 */
- (void)asdk_diffWithArray:(NSArray *)array insertions:(NSIndexSet **)insertions deletions:(NSIndexSet **)deletions compareBlock:(BOOL (^)(id lhs, id rhs))comparison;

@end
