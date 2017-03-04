//
//  ASTextNodePerformanceTests.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "ASPerformanceTestContext.h"
#import <AsyncDisplayKit/ASTextNode.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import "ASXCTExtensions.h"
#import <AsyncDisplayKit/CoreGraphics+ASConvenience.h>

/**
 * NOTE: This test case is not run during the "test" action. You have to run it manually (click the little diamond.)
 */

@interface ASTextNodePerformanceTests : XCTestCase

@end

@implementation ASTextNodePerformanceTests

#pragma mark Performance Tests

static NSString *const kTestCaseUIKit = @"UIKit";
static NSString *const kTestCaseASDK = @"ASDK";
static NSString *const kTestCaseUIKitPrivateCaching = @"UIKitPrivateCaching";
static NSString *const kTestCaseUIKitWithNoContext = @"UIKitNoContext";
static NSString *const kTestCaseUIKitWithFreshContext = @"UIKitFreshContext";
static NSString *const kTestCaseUIKitWithReusedContext = @"UIKitReusedContext";

+ (NSArray<NSAttributedString *> *)realisticDataSet
{
  static NSArray *array;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSString *file = [[NSBundle bundleForClass:self] pathForResource:@"AttributedStringsFixture0" ofType:@"plist" inDirectory:@"TestResources"];
    if (file != nil) {
    	array = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
    }
    NSAssert([array isKindOfClass:[NSArray class]], nil);
    NSSet *unique = [NSSet setWithArray:array];
    NSLog(@"Loaded realistic text data set with %d attributed strings, %d unique.", (int)array.count, (int)unique.count);
  });
  return array;
}

- (void)testPerformance_RealisticData
{
  NSArray *data = [self.class realisticDataSet];

  CGSize maxSize = CGSizeMake(355, CGFLOAT_MAX);
  CGSize __block uiKitSize, __block asdkSize;

  ASPerformanceTestContext *ctx = [[ASPerformanceTestContext alloc] init];
  [ctx addCaseWithName:kTestCaseUIKit block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    NSAttributedString *text = data[i % data.count];
    startMeasuring();
    uiKitSize = [text boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine context:nil].size;
    stopMeasuring();
  }];
  uiKitSize.width = ASCeilPixelValue(uiKitSize.width);
  uiKitSize.height = ASCeilPixelValue(uiKitSize.height);
  ctx.results[kTestCaseUIKit].userInfo[@"size"] = NSStringFromCGSize(uiKitSize);

  [ctx addCaseWithName:kTestCaseASDK block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    ASTextNode *node = [[ASTextNode alloc] init];
    NSAttributedString *text = data[i % data.count];
    startMeasuring();
    node.attributedText = text;
    asdkSize = [node layoutThatFits:ASSizeRangeMake(CGSizeZero, maxSize)].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseASDK].userInfo[@"size"] = NSStringFromCGSize(asdkSize);

  ASXCTAssertEqualSizes(uiKitSize, asdkSize);
  ASXCTAssertRelativePerformanceInRange(ctx, kTestCaseASDK, 0.2, 0.5);
}

- (void)testPerformance_TwoParagraphLatinNoTruncation
{
  NSAttributedString *text = [ASTextNodePerformanceTests twoParagraphLatinText];
  
  CGSize maxSize = CGSizeMake(355, CGFLOAT_MAX);
  CGSize __block uiKitSize, __block asdkSize;
  
  ASPerformanceTestContext *ctx = [[ASPerformanceTestContext alloc] init];
  [ctx addCaseWithName:kTestCaseUIKit block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
    uiKitSize = [text boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine context:nil].size;
    stopMeasuring();
  }];
  uiKitSize.width = ASCeilPixelValue(uiKitSize.width);
  uiKitSize.height = ASCeilPixelValue(uiKitSize.height);
  ctx.results[kTestCaseUIKit].userInfo[@"size"] = NSStringFromCGSize(uiKitSize);
  
  [ctx addCaseWithName:kTestCaseASDK block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    ASTextNode *node = [[ASTextNode alloc] init];
    startMeasuring();
    node.attributedText = text;
    asdkSize = [node layoutThatFits:ASSizeRangeMake(CGSizeZero, maxSize)].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseASDK].userInfo[@"size"] = NSStringFromCGSize(asdkSize);
  
  ASXCTAssertEqualSizes(uiKitSize, asdkSize);
  ASXCTAssertRelativePerformanceInRange(ctx, kTestCaseASDK, 0.5, 0.9);
}

- (void)testPerformance_OneParagraphLatinWithTruncation
{
  NSAttributedString *text = [ASTextNodePerformanceTests oneParagraphLatinText];
  
  CGSize maxSize = CGSizeMake(355, 150);
  CGSize __block uiKitSize, __block asdkSize;
  
  ASPerformanceTestContext *testCtx = [[ASPerformanceTestContext alloc] init];
  [testCtx addCaseWithName:kTestCaseUIKit block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
    uiKitSize = [text boundingRectWithSize:maxSize options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine context:nil].size;
    stopMeasuring();
  }];
  uiKitSize.width = ASCeilPixelValue(uiKitSize.width);
  uiKitSize.height = ASCeilPixelValue(uiKitSize.height);
  testCtx.results[kTestCaseUIKit].userInfo[@"size"] = NSStringFromCGSize(uiKitSize);
  
  [testCtx addCaseWithName:kTestCaseASDK block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    ASTextNode *node = [[ASTextNode alloc] init];
    startMeasuring();
    node.attributedText = text;
    asdkSize = [node layoutThatFits:ASSizeRangeMake(CGSizeZero, maxSize)].size;
    stopMeasuring();
  }];
  testCtx.results[kTestCaseASDK].userInfo[@"size"] = NSStringFromCGSize(asdkSize);
  
  XCTAssert(CGSizeEqualToSizeWithIn(uiKitSize, asdkSize, 5));
  ASXCTAssertRelativePerformanceInRange(testCtx, kTestCaseASDK, 0.1, 0.3);
}

- (void)testThatNotUsingAStringDrawingContextHasSimilarPerformanceToHavingOne
{
  ASPerformanceTestContext *ctx = [[ASPerformanceTestContext alloc] init];
  
  NSAttributedString *text = [ASTextNodePerformanceTests oneParagraphLatinText];
  CGSize maxSize = CGSizeMake(355, 150);
  NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;
  __block CGSize size;
  // nil context
  [ctx addCaseWithName:kTestCaseUIKitWithNoContext block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
    size = [text boundingRectWithSize:maxSize options:options context:nil].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseUIKitWithNoContext].userInfo[@"size"] = NSStringFromCGSize(size);
  
  // Fresh context
  [ctx addCaseWithName:kTestCaseUIKitWithFreshContext block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    NSStringDrawingContext *stringDrawingCtx = [[NSStringDrawingContext alloc] init];
    startMeasuring();
      size = [text boundingRectWithSize:maxSize options:options context:stringDrawingCtx].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseUIKitWithFreshContext].userInfo[@"size"] = NSStringFromCGSize(size);
  
  // Reused context
  NSStringDrawingContext *stringDrawingCtx = [[NSStringDrawingContext alloc] init];
  [ctx addCaseWithName:kTestCaseUIKitWithReusedContext block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
      size = [text boundingRectWithSize:maxSize options:options context:stringDrawingCtx].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseUIKitWithReusedContext].userInfo[@"size"] = NSStringFromCGSize(size);
  
  XCTAssertTrue([ctx areAllUserInfosEqual]);
  ASXCTAssertRelativePerformanceInRange(ctx, kTestCaseUIKitWithReusedContext, 0.8, 1.2);
  ASXCTAssertRelativePerformanceInRange(ctx, kTestCaseUIKitWithFreshContext, 0.8, 1.2);
}

- (void)testThatUIKitPrivateLayoutCachingIsAwesome
{
  NSAttributedString *text = [ASTextNodePerformanceTests oneParagraphLatinText];
  ASPerformanceTestContext *ctx = [[ASPerformanceTestContext alloc] init];
  CGSize maxSize = CGSizeMake(355, 150);
  __block CGSize uncachedSize, cachedSize;
  NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine;
  
  // No caching, reused ctx
  NSStringDrawingContext *defaultCtx = [[NSStringDrawingContext alloc] init];
  XCTAssertFalse([[defaultCtx valueForKey:@"cachesLayout"] boolValue]);
  [ctx addCaseWithName:kTestCaseUIKit block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
    uncachedSize = [text boundingRectWithSize:maxSize options:options context:defaultCtx].size;
    stopMeasuring();
  }];
  XCTAssertFalse([[defaultCtx valueForKey:@"cachesLayout"] boolValue]);
  ctx.results[kTestCaseUIKit].userInfo[@"size"] = NSStringFromCGSize(uncachedSize);
  
  // Caching
  NSStringDrawingContext *cachingCtx = [[NSStringDrawingContext alloc] init];
  [cachingCtx setValue:@YES forKey:@"cachesLayout"];
  [ctx addCaseWithName:kTestCaseUIKitPrivateCaching block:^(NSUInteger i, dispatch_block_t  _Nonnull startMeasuring, dispatch_block_t  _Nonnull stopMeasuring) {
    startMeasuring();
    cachedSize = [text boundingRectWithSize:maxSize options:options context:cachingCtx].size;
    stopMeasuring();
  }];
  ctx.results[kTestCaseUIKitPrivateCaching].userInfo[@"size"] = NSStringFromCGSize(cachedSize);
  
  XCTAssertTrue([ctx areAllUserInfosEqual]);
  ASXCTAssertRelativePerformanceInRange(ctx, kTestCaseUIKitPrivateCaching, 1.2, FLT_MAX);
}

#pragma mark Fixture Data

+ (NSMutableAttributedString *)oneParagraphLatinText
{
  NSDictionary *attributes = @{
                               NSFontAttributeName: [UIFont systemFontOfSize:14]
                               };
  return [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam gravida, metus non tincidunt tincidunt, arcu quam vulputate magna, nec semper libero mi in lorem. Quisque turpis erat, congue sit amet eros at, gravida gravida lacus. Maecenas maximus lectus in efficitur pulvinar. Nam elementum massa eget luctus condimentum. Curabitur egestas mauris urna. Fusce lacus ante, laoreet vitae leo quis, mattis aliquam est. Donec bibendum augue at elit lacinia lobortis. Cras imperdiet ac justo eget sollicitudin. Pellentesque malesuada nec tellus vitae dictum. Proin vestibulum tempus odio in condimentum. Interdum et malesuada fames ac ante ipsum primis in faucibus. Duis vel turpis at velit dignissim rutrum. Nunc lorem felis, molestie eget ornare id, luctus at nunc. Maecenas suscipit nisi sit amet nulla cursus, id eleifend odio laoreet." attributes:attributes];
}

+ (NSMutableAttributedString *)twoParagraphLatinText
{
  NSDictionary *attributes = @{
                               NSFontAttributeName: [UIFont systemFontOfSize:14]
                               };
  return [[NSMutableAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam gravida, metus non tincidunt tincidunt, arcu quam vulputate magna, nec semper libero mi in lorem. Quisque turpis erat, congue sit amet eros at, gravida gravida lacus. Maecenas maximus lectus in efficitur pulvinar. Nam elementum massa eget luctus condimentum. Curabitur egestas mauris urna. Fusce lacus ante, laoreet vitae leo quis, mattis aliquam est. Donec bibendum augue at elit lacinia lobortis. Cras imperdiet ac justo eget sollicitudin. Pellentesque malesuada nec tellus vitae dictum. Proin vestibulum tempus odio in condimentum. Interdum et malesuada fames ac ante ipsum primis in faucibus. Duis vel turpis at velit dignissim rutrum. Nunc lorem felis, molestie eget ornare id, luctus at nunc. Maecenas suscipit nisi sit amet nulla cursus, id eleifend odio laoreet.\n\nPellentesque auctor pulvinar velit, venenatis elementum ex tempus eu. Vestibulum iaculis hendrerit tortor quis sagittis. Pellentesque quam sem, varius ac orci nec, tincidunt ultricies mauris. Aliquam est nunc, eleifend et posuere sed, vestibulum eu elit. Pellentesque pharetra bibendum finibus. Aliquam interdum metus ac feugiat congue. Donec suscipit neque quis mauris volutpat, at molestie tortor aliquam. Aenean posuere nulla a ex posuere finibus. Integer tincidunt quam urna, et vulputate enim tempor sit amet. Nullam ut tellus ac arcu fringilla cursus." attributes:attributes];
}
@end
