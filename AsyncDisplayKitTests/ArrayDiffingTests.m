//
//  ArrayDiffingTests.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 1/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NSArray+Diffing.h"

@interface ArrayDiffingTests : XCTestCase

@end

@implementation ArrayDiffingTests

- (void)testDiffing {
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
