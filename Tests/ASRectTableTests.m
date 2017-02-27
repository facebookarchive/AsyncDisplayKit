//
//  ASRectTableTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ASRectTable.h"
#import "ASXCTExtensions.h"

@interface ASRectTableTests : XCTestCase
@end

@implementation ASRectTableTests

- (void)testThatItStoresRects
{
  ASRectTable *table = [ASRectTable rectTableForWeakObjectPointers];
  NSObject *key0 = [[NSObject alloc] init];
  NSObject *key1 = [[NSObject alloc] init];
  ASXCTAssertEqualRects([table rectForKey:key0], CGRectNull);
  ASXCTAssertEqualRects([table rectForKey:key1], CGRectNull);
  CGRect rect0 = CGRectMake(0, 0, 100, 100);
  CGRect rect1 = CGRectMake(0, 0, 50, 50);
  [table setRect:rect0 forKey:key0];
  [table setRect:rect1 forKey:key1];

  ASXCTAssertEqualRects([table rectForKey:key0], rect0);
  ASXCTAssertEqualRects([table rectForKey:key1], rect1);
}


- (void)testCopying
{
  ASRectTable *table = [ASRectTable rectTableForWeakObjectPointers];
  NSObject *key = [[NSObject alloc] init];
  ASXCTAssertEqualRects([table rectForKey:key], CGRectNull);
  CGRect rect0 = CGRectMake(0, 0, 100, 100);
  CGRect rect1 = CGRectMake(0, 0, 50, 50);
  [table setRect:rect0 forKey:key];
  ASRectTable *copy = [table copy];
  [copy setRect:rect1 forKey:key];

  ASXCTAssertEqualRects([table rectForKey:key], rect0);
  ASXCTAssertEqualRects([copy rectForKey:key], rect1);
}

@end
