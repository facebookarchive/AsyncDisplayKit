//
//  ASWeakMapTests.m
//  AsyncDisplayKit
//
//  Created by Chris Danford on 7/23/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>
#import "ASWeakMap.h"

NS_ASSUME_NONNULL_BEGIN

@interface ASWeakMapTests : XCTestCase

@end

@implementation ASWeakMapTests

- (void)testKeyAndValueAreReleasedWhenEntryIsReleased
{
  ASWeakMap <NSObject *, NSObject *> *weakMap = [[ASWeakMap alloc] init];

  __weak NSObject *weakKey;
  __weak NSObject *weakValue;
  @autoreleasepool {
    NSObject *key = [[NSObject alloc] init];
    NSObject *value = [[NSObject alloc] init];
    ASWeakMapEntry *entry = [weakMap setObject:value forKey:key];
    XCTAssertEqual([weakMap entryForKey:key], entry);

    weakKey = key;
    weakValue = value;
}
  XCTAssertEqual(weakKey, nil);
  XCTAssertEqual(weakValue, nil);
}

- (void)testKeyEquality
{
  ASWeakMap <NSString *, NSObject *> *weakMap = [[ASWeakMap alloc] init];
  NSString *keyA = @"key";
  NSString *keyB = [keyA copy];  // `isEqual` but not pointer equal
  NSObject *value = [[NSObject alloc] init];
  
  ASWeakMapEntry *entryA = [weakMap setObject:value forKey:keyA];
  ASWeakMapEntry *entryB = [weakMap entryForKey:keyB];
  XCTAssertEqual(entryA, entryB);
}

@end

NS_ASSUME_NONNULL_END
