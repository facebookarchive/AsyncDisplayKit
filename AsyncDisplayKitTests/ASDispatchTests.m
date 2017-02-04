//
//  ASDispatchTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <AsyncDisplayKit/ASDispatch.h>

@interface ASDispatchTests : XCTestCase

@end

@implementation ASDispatchTests

- (void)testDispatchApply
{
  dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  NSInteger expectedThreadCount = [NSProcessInfo processInfo].activeProcessorCount * 2;
  NSLock *lock = [NSLock new];
  NSMutableSet *threads = [NSMutableSet set];
  NSMutableIndexSet *indices = [NSMutableIndexSet indexSet];
  
  size_t const iterations = 1E5;
  ASDispatchApply(iterations, q, 0, ^(size_t i) {
    [lock lock];
    [threads addObject:[NSThread currentThread]];
    XCTAssertFalse([indices containsIndex:i]);
    [indices addIndex:i];
    [lock unlock];
  });
  XCTAssertLessThanOrEqual(threads.count, expectedThreadCount);
  XCTAssertEqualObjects(indices, [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, iterations)]);
}

@end
