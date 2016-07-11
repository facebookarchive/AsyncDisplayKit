//
//  ASWeakSet.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASWeakSet.h"

@interface ASWeakSet<__covariant ObjectType> ()
@property (nonatomic, strong, readonly) NSMapTable<ObjectType, NSNull *> *mapTable;
@end

@implementation ASWeakSet

- (instancetype)init
{
  self = [super init];
  if (self) {
    _mapTable = [NSMapTable weakToStrongObjectsMapTable];
  }
  return self;
}

- (void)addObject:(id)object
{
  [_mapTable setObject:(NSNull *)kCFNull forKey:object];
}

- (void)removeObject:(id)object
{
  [_mapTable removeObjectForKey:object];
}

- (void)removeAllObjects
{
  [_mapTable removeAllObjects];
}

- (NSArray *)allObjects
{
  // We use keys instead of values in the map table for efficiency and better characteristics when the keys are deallocated.
  // Documentation is currently unclear on whether -keyEnumerator retains its values, but does imply that modifying a
  // mutable collection is still not safe while enumerating that way - which is one of the main uses for this method.
  // A helper function called NSAllMapTableKeys() might do exactly what we want and should be more efficient, but unfortunately
  // is throwing a strange compiler error and may not be available in practice on the latest iOS version.
  // Lastly, even -dictionaryRepresentation and then -allKeys won't work, because it attempts to copy the values of each key,
  // which may not support copying (such as ASRangeControllers).
  NSMutableArray *allObjects = [NSMutableArray array];
  for (id object in _mapTable) {
    [allObjects addObject:object];
  }
  return allObjects;
}

- (BOOL)containsObject:(id)object
{
  return [_mapTable objectForKey:object] != nil;
}

- (BOOL)isEmpty
{
  for (__unused id object in _mapTable) {
    return NO;
  }
  return YES;
}

/**
 Note: The `count` property of NSMapTable is unreliable
 in the case of weak-to-strong map tables because entries
 whose keys have been deallocated are not removed immediately.
 
 In order to get the true count we have to fall back to using
 fast enumeration.
 */
- (NSUInteger)count
{
  NSUInteger count = 0;
  for (__unused id object in _mapTable) {
    count += 1;
  }
  return count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nonnull *)buffer count:(NSUInteger)len
{
  return [_mapTable countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)description
{
  return [[super description] stringByAppendingFormat:@" count: %lu, contents: %@", (unsigned long)self.count, _mapTable];
}

@end
