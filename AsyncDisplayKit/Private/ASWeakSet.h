//
//  ASWeakSet.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
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

/**
 How many objects are contained in this set.
 
 NOTE: This method is O(N). Consider using the `empty`
 property.
 */
@property (nonatomic, readonly) NSUInteger count;

@end

NS_ASSUME_NONNULL_END