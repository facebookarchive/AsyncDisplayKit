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

#import <AsyncDisplayKit/ASWeakSet.h>

@interface ASWeakSet<__covariant ObjectType> ()
@property (nonatomic, strong, readonly) NSHashTable<ObjectType> *hashTable;
@end

@implementation ASWeakSet

- (instancetype)init
{
  self = [super init];
  if (self) {
    _hashTable = [NSHashTable hashTableWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality];
  }
  return self;
}

- (void)addObject:(id)object
{
  [_hashTable addObject:object];
}

- (void)removeObject:(id)object
{
  [_hashTable removeObject:object];
}

- (void)removeAllObjects
{
  [_hashTable removeAllObjects];
}

- (NSArray *)allObjects
{
  return _hashTable.allObjects;
}

- (BOOL)containsObject:(id)object
{
  return [_hashTable containsObject:object];
}

- (BOOL)isEmpty
{
  return [_hashTable anyObject] == nil;
}

/**
 Note: The `count` property of NSHashTable is unreliable
 in the case of weak-memory hash tables because entries
 that have been deallocated are not removed immediately.
 
 In order to get the true count we have to fall back to using
 fast enumeration.
 */
- (NSUInteger)count
{
  NSUInteger count = 0;
  for (__unused id object in _hashTable) {
    count += 1;
  }
  return count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nonnull *)buffer count:(NSUInteger)len
{
  return [_hashTable countByEnumeratingWithState:state objects:buffer count:len];
}

- (NSString *)description
{
  return [[super description] stringByAppendingFormat:@" count: %tu, contents: %@", self.count, _hashTable];
}

@end
