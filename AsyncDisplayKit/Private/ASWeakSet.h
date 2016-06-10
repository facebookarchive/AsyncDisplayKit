//
//  ASWeakSet.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASWeakSet<__covariant ObjectType> : NSObject<NSFastEnumeration>

/// Returns YES if the receiver is empty, NO otherwise.
@property (nonatomic, readonly, getter=isEmpty) BOOL empty;

/// Returns YES if `object` is in the receiver, NO otherwise.
- (BOOL)containsObject:(ObjectType)object;

/// Insets `object` into the set.
- (void)addObject:(ObjectType)object;

/// Removes object from the set.
- (void)removeObject:(ObjectType)object;

/// Removes all objects from the set.
- (void)removeAllObjects;

/// Returns a standard *retained* NSArray of all objects.  Not free to generate, but useful for iterating over contents.
- (NSArray *)allObjects;

/**
 How many objects are contained in this set.
 
 NOTE: This method is O(N). Consider using the `empty`
 property.
 */
@property (nonatomic, readonly) NSUInteger count;

@end

NS_ASSUME_NONNULL_END