//
//  ASWeakMap.h
//  AsyncDisplayKit
//
//  Created by Chris Danford on 7/11/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN


/**
 * This class is used in conjunction with ASWeakMap.  Instances of this type are returned by an ASWeakMap,
 * must retain this value for as long as they want the entry to exist in the map.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASWeakMapEntry<Value> : NSObject

@property (nonatomic, retain, readonly) Value value;

@end


/**
 * This is not a full-featured map.  It does not support features like `count` and FastEnumeration because there
 * is not currently a need.
 *
 * This is a map that does not retain keys or values added to it.  When both getting and setting, the caller is
 * returned a ASWeakMapEntry and must retain it for as long as it wishes the key/value to remain in the map.
 * We return a single Entry value to the caller to avoid two potential problems:
 *
 * 1) It's easier for callers to retain one value (the Entry) and not two (a key and a value).
 * 2) Key values are tested for `isEqual` equality.  If if a caller asks for a key "A" that is equal to a key "B"
 *    already in the map, then we need the caller to retain key "B" and not key "A".  Returning an Entry simplifies
 *    the semantics.
 *
 * The underlying storage is a hash table and the Key type should implement `hash` and `isEqual:`.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASWeakMap<__covariant Key : NSObject *, Value> : NSObject

/**
 * Read from the cache.  The Value object is accessible from the returned ASWeakMapEntry.
 */
- (nullable ASWeakMapEntry<Value> *)entryForKey:(Key)key AS_WARN_UNUSED_RESULT;

/**
 * Put a value into the cache.  If an entry with an equal key already exists, then the value is updated on the existing entry.
 */
- (ASWeakMapEntry<Value> *)setObject:(Value)value forKey:(Key)key AS_WARN_UNUSED_RESULT;

@end


NS_ASSUME_NONNULL_END
