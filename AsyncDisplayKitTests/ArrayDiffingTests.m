//
//  ArrayDiffingTests.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>

#import "NSArray+Diffing.h"

@interface NSArray (ArrayDiffingTests)
- (NSIndexSet *)_asdk_commonIndexesWithArray:(NSArray *)array selfHashes:(NSUInteger *)selfHashes arrayHashes:(NSUInteger *)arrayHashes compareBlock:(BOOL (^)(id lhs, id rhs))comparison;
@end

@interface ArrayDiffingTests : XCTestCase

@end

@implementation ArrayDiffingTests

- (void)testDiffingCommonIndexes
{
  NSArray<NSArray *> *tests = @[
    @[
      @[@"bob", @"alice", @"dave"],
      @[@"bob", @"alice", @"dave", @"gary"],
      @[@0, @1, @2]
    ],
    @[
      @[@"bob", @"alice", @"dave"],
      @[@"bob", @"gary", @"dave"],
      @[@0, @2]
    ],
    @[
      @[@"bob", @"alice"],
      @[@"gary", @"dave"],
      @[],
    ],
    @[
      @[@"bob", @"alice", @"dave"],
      @[],
      @[],
    ],
    @[
      @[],
      @[@"bob", @"alice", @"dave"],
      @[],
    ],
  ];

  for (NSArray *test in tests) {
    NSIndexSet *indexSet = [test[0] _asdk_commonIndexesWithArray:test[1] selfHashes:NULL arrayHashes:NULL compareBlock:^BOOL(id lhs, id rhs) {
      return [lhs isEqual:rhs];
    }];
    
    for (NSNumber *index in (NSArray *)test[2]) {
      XCTAssert([indexSet containsIndex:[index integerValue]]);
    }
  }
}

- (void)testDiffingInsertionsAndDeletions {
  NSArray<NSArray *> *tests = @[
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"alice", @"dave", @"gary"],
        @[@3],
        @[],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"gary", @"alice", @"dave"],
        @[@1],
        @[],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"bob", @"alice"],
        @[],
        @[@2],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[],
        @[],
        @[@0, @1, @2],
      ],
      @[
        @[@"bob", @"alice", @"dave"],
        @[@"gary", @"alice", @"dave", @"jack"],
        @[@0, @3],
        @[@0],
      ],
      @[
        @[@"bob", @"alice", @"dave", @"judy", @"lynda", @"tony"],
        @[@"gary", @"bob", @"suzy", @"tony"],
        @[@0, @2],
        @[@1, @2, @3, @4],
      ],
      @[
        @[@"bob", @"alice", @"dave", @"judy"],
        @[@"judy", @"dave", @"alice", @"bob"],
        @[@1, @2, @3],
        @[@0, @1, @2],
      ],
  ];
  
  for (NSArray *test in tests) {
    NSIndexSet *insertions, *deletions;
    [test[0] asdk_diffWithArray:test[1] insertions:&insertions deletions:&deletions];
    for (NSNumber *index in (NSArray *)test[2]) {
      XCTAssert([insertions containsIndex:[index integerValue]]);
    }
    for (NSNumber *index in (NSArray *)test[3]) {
      XCTAssert([deletions containsIndex:[index integerValue]]);
    }
  }
}

@end
