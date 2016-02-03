/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <XCTest/XCTest.h>

#import "ASBatchFetching.h"

@interface ASBatchFetchingTests : XCTestCase

@end

@implementation ASBatchFetchingTests

#define PASSING_RECT CGRectMake(0,0,1,1)
#define PASSING_SIZE CGSizeMake(1,1)
#define PASSING_POINT CGPointMake(1,1)
#define VERTICAL_RECT(h) CGRectMake(0,0,0,h)
#define VERTICAL_SIZE(h) CGSizeMake(0,h)
#define VERTICAL_OFFSET(y) CGPointMake(0,y)
#define HORIZONTAL_RECT(w) CGRectMake(0,0,w,0)
#define HORIZONTAL_SIZE(w) CGSizeMake(w,0)
#define HORIZONTAL_OFFSET(x) CGPointMake(x,0)

- (void)testBatchNullState {
  ASBatchContext *context = [[ASBatchContext alloc] init];
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, CGRectZero, CGSizeZero, CGPointZero, 0.0, 0.0);
  XCTAssert(shouldFetch == NO, @"Should not fetch in the null state");
}

- (void)testBatchAlreadyFetching {
  ASBatchContext *context = [[ASBatchContext alloc] init];
  [context beginBatchFetching];
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, PASSING_RECT, PASSING_SIZE, PASSING_POINT, 1.0, 1.0);
  XCTAssert(shouldFetch == NO, @"Should not fetch when context is already fetching");
}

- (void)testSupportedScrollDirections {
  ASBatchContext *context = [[ASBatchContext alloc] init];
  BOOL fetchRight = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionRight, NO, PASSING_RECT, PASSING_SIZE, PASSING_POINT, 1.0, 1.0);
  XCTAssert(fetchRight == YES, @"Should fetch for scrolling right");
  BOOL fetchDown = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionDown, NO, PASSING_RECT, PASSING_SIZE, PASSING_POINT, 1.0, 1.0);
  XCTAssert(fetchDown == YES, @"Should fetch for scrolling down");
  BOOL fetchUp = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, PASSING_RECT, PASSING_SIZE, PASSING_POINT, 1.0, 1.0);
  XCTAssert(fetchUp == YES, @"Should fetch for scrolling up");
  BOOL fetchLeft = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionLeft, YES, PASSING_RECT, PASSING_SIZE, PASSING_POINT, 1.0, 1.0);
  XCTAssert(fetchLeft == YES, @"Should fetch for scrolling left");
}

- (void)testVerticalScrollToExactLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // scroll to 1-screen top offset, height is 1 screen, so bottom is 1 screen away from end of content
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(screen * 1.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when vertically scrolling to exactly 1 leading screen away");
}

- (void)testVerticalScrollToExactTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // scroll to 2-screen top offset, height is 1 screen, so top is 1 screen away from end of content
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionDown, NO, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(screen * 2.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when vertically scrolling to exactly 1 trailing screen away");
}

- (void)testVerticalScrollToLessThanLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, scroll only 1/2 of one screen
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(screen * 0.5), 1.0, 1.0);
  XCTAssert(shouldFetch == NO, @"Fetch should not begin when vertically scrolling less than the leading distance away");
}
- (void)testVerticalScrollToLessThanTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, scroll only 1/2 of one screen
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionDown, NO, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(screen * 2.5), 1.0, 1.0);
  XCTAssert(shouldFetch == NO, @"Fetch should not begin when vertically scrolling less than the trailing distance away");
}

- (void)testVerticalScrollingPastContentSize {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, top offset to 3-screens, height 1 screen, so its 1 screen past the leading
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(screen * 3.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when vertically scrolling past the content size");
}

- (void)testVerticalScrollingNegativePastContentSize {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, top offset to 0, height 1 screen, so its 1 screen past the trailing
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionDown, NO, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 3.0), VERTICAL_OFFSET(0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when vertically scrolling past the content size");
}

- (void)testHorizontalScrollToExactLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // scroll to 1-screen left offset, width is 1 screen, so right is 1 screen away from end of content
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionLeft, YES, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(screen * 1.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when horizontally scrolling to exactly 1 leading screen away");
}

- (void)testHorizontalScrollToExactTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // scroll to 2-screen left offset, width is 1 screen, so left is 1 screen away from end of content
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionRight, NO, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(screen * 2.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when horizontally scrolling to exactly 1 leading screen away");
}

- (void)testHorizontalScrollToLessThanLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, scroll only 1/2 of one screen
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionLeft, YES, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(screen * 0.5), 1.0, 1.0);
  XCTAssert(shouldFetch == NO, @"Fetch should not begin when horizontally scrolling less than the leading distance away");
}

- (void)testHorizontalScrollToLessThanTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, scroll only 1/2 of one screen
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionRight, NO, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(screen * 2.5), 1.0, 1.0);
  XCTAssert(shouldFetch == NO, @"Fetch should not begin when horizontally scrolling less than the leading distance away");
}

- (void)testHorizontalScrollingPastContentSize {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, left offset to 3-screens, width 1 screen, so its 1 screen past the leading
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionLeft, YES, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(screen * 3.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when horizontally scrolling past the content size");
}

- (void)testHorizontalScrollingNegativePastContentSize {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // 3 screens of content, left offset to 0, width 1 screen, so its 1 screen past the trailing
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionRight, NO, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 3.0), HORIZONTAL_OFFSET(0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when horizontally scrolling past the content size");
}

- (void)testVerticalScrollingSmallContentSizeLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // when the content size is < screen size, the target offset will always be 0
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionUp, YES, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 0.5), VERTICAL_OFFSET(0.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when the target is 0 and the content size is smaller than the screen");
}

- (void)testVerticalScrollingSmallContentSizeTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // when the content size is < screen size, the target offset will always be 0
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionDown, NO, VERTICAL_RECT(screen), VERTICAL_SIZE(screen * 0.5), VERTICAL_OFFSET(0.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when the target is 0 and the content size is smaller than the screen");
}

- (void)testHorizontalScrollingSmallContentSizeLeading {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // when the content size is < screen size, the target offset will always be 0
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionLeft, YES, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 0.5), HORIZONTAL_OFFSET(0.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when the target is 0 and the content size is smaller than the screen");
}

- (void)testHorizontalScrollingSmallContentSizeTrailing {
  CGFloat screen = 1.0;
  ASBatchContext *context = [[ASBatchContext alloc] init];
  // when the content size is < screen size, the target offset will always be 0
  BOOL shouldFetch = ASDisplayShouldFetchBatchForContext(context, ASScrollDirectionRight, NO, HORIZONTAL_RECT(screen), HORIZONTAL_SIZE(screen * 0.5), HORIZONTAL_OFFSET(0.0), 1.0, 1.0);
  XCTAssert(shouldFetch == YES, @"Fetch should begin when the target is 0 and the content size is smaller than the screen");
}

@end
