//
//  ASPerformanceTestContext.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 8/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTestAssertionsImpl.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#define ASXCTAssertRelativePerformanceInRange(test, caseName, min, max) \
  _XCTPrimitiveAssertLessThanOrEqual(self, test.results[caseName].relativePerformance, @#caseName, max, @#max);\
  _XCTPrimitiveAssertGreaterThanOrEqual(self, test.results[caseName].relativePerformance, @#caseName, min, @#min)

NS_ASSUME_NONNULL_BEGIN

typedef void (^ASTestPerformanceCaseBlock)(NSUInteger i, dispatch_block_t startMeasuring, dispatch_block_t stopMeasuring);

@interface ASPerformanceTestResult : NSObject
@property (nonatomic, readonly) NSTimeInterval timePer1000;
@property (nonatomic, readonly) NSString *caseName;

@property (nonatomic, readonly, getter=isReferenceCase) BOOL referenceCase;
@property (nonatomic, readonly) float relativePerformance;

@property (nonatomic, readonly) NSMutableDictionary *userInfo;
@end

@interface ASPerformanceTestContext : NSObject

/**
 * The first case you add here will be considered the reference case.
 */
- (void)addCaseWithName:(NSString *)caseName block:(AS_NOESCAPE ASTestPerformanceCaseBlock)block;

@property (nonatomic, copy, readonly) NSDictionary<NSString *, ASPerformanceTestResult *> *results;

- (BOOL)areAllUserInfosEqual;

@end

NS_ASSUME_NONNULL_END
