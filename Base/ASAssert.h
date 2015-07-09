/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#pragma once

#import <Foundation/NSException.h>

#define ASDisplayNodeAssertWithSignalAndLogFunction(condition, description, logFunction, ...) NSAssert(condition, description, ##__VA_ARGS__);
#define ASDisplayNodeCAssertWithSignalAndLogFunction(condition, description, logFunction, ...) NSCAssert(condition, description, ##__VA_ARGS__);
#define ASDisplayNodeAssertWithSignal(condition, description, ...) NSAssert(condition, description, ##__VA_ARGS__)
#define ASDisplayNodeCAssertWithSignal(condition, description, ...) NSCAssert(condition, description, ##__VA_ARGS__)

#define ASDISPLAYNODE_ASSERTIONS_ENABLED (!defined(NS_BLOCK_ASSERTIONS))

#define ASDisplayNodeAssert(...) NSAssert(__VA_ARGS__)
#define ASDisplayNodeCAssert(...) NSCAssert(__VA_ARGS__)

#define ASDisplayNodeAssertNil(condition, description, ...) ASDisplayNodeAssertWithSignal(!(condition), nil, (description), ##__VA_ARGS__)
#define ASDisplayNodeCAssertNil(condition, description, ...) ASDisplayNodeCAssertWithSignal(!(condition), nil, (description), ##__VA_ARGS__)

#define ASDisplayNodeAssertNotNil(condition, description, ...) ASDisplayNodeAssertWithSignal((condition), nil, (description), ##__VA_ARGS__)
#define ASDisplayNodeCAssertNotNil(condition, description, ...) ASDisplayNodeCAssertWithSignal((condition), nil, (description), ##__VA_ARGS__)

#define ASDisplayNodeAssertImplementedBySubclass() ASDisplayNodeAssertWithSignal(NO, nil, @"This method must be implemented by subclass %@", [self class]);
#define ASDisplayNodeAssertNotInstantiable() ASDisplayNodeAssertWithSignal(NO, nil, @"This class is not instantiable.");
#define ASDisplayNodeAssertNotSupported() ASDisplayNodeAssertWithSignal(NO, nil, @"This method is not supported by class %@", [self class]);

#define ASDisplayNodeAssertMainThread() ASDisplayNodeAssertWithSignal([NSThread isMainThread], nil, @"This method must be called on the main thread")
#define ASDisplayNodeCAssertMainThread() ASDisplayNodeCAssertWithSignal([NSThread isMainThread], nil, @"This function must be called on the main thread")

#define ASDisplayNodeAssertNotMainThread() ASDisplayNodeAssertWithSignal(![NSThread isMainThread], nil, @"This method must be called off the main thread")
#define ASDisplayNodeCAssertNotMainThread() ASDisplayNodeCAssertWithSignal(![NSThread isMainThread], nil, @"This function must be called off the main thread")

#define ASDisplayNodeAssertFlag(X) ASDisplayNodeAssertWithSignal((1 == __builtin_popcount(X)), nil, nil)
#define ASDisplayNodeCAssertFlag(X) ASDisplayNodeCAssertWithSignal((1 == __builtin_popcount(X)), nil, nil)

#define ASDisplayNodeAssertTrue(condition) ASDisplayNodeAssertWithSignal((condition), nil, nil)
#define ASDisplayNodeCAssertTrue(condition) ASDisplayNodeCAssertWithSignal((condition), nil, nil)

#define ASDisplayNodeAssertFalse(condition) ASDisplayNodeAssertWithSignal(!(condition), nil, nil)
#define ASDisplayNodeCAssertFalse(condition) ASDisplayNodeCAssertWithSignal(!(condition), nil, nil)

#define ASDisplayNodeFailAssert(description, ...) ASDisplayNodeAssertWithSignal(NO, nil, (description), ##__VA_ARGS__)
#define ASDisplayNodeCFailAssert(description, ...) ASDisplayNodeCAssertWithSignal(NO, nil, (description), ##__VA_ARGS__)

#define ASDisplayNodeConditionalAssert(shouldTestCondition, condition, description, ...) ASDisplayNodeAssert((!(shouldTestCondition) || (condition)), nil, (description), ##__VA_ARGS__)
#define ASDisplayNodeConditionalCAssert(shouldTestCondition, condition, description, ...) ASDisplayNodeCAssert((!(shouldTestCondition) || (condition)), nil, (description), ##__VA_ARGS__)

#define ASDisplayNodeCAssertPositiveReal(description, num) ASDisplayNodeCAssert(num >= 0 && num <= CGFLOAT_MAX, @"%@ must be a real positive integer.", description)
#define ASDisplayNodeCAssertInfOrPositiveReal(description, num) ASDisplayNodeCAssert(isinf(num) || (num >= 0 && num <= CGFLOAT_MAX), @"%@ must be infinite or a real positive integer.", description)

