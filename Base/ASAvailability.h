/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Availability.h>
#import <AvailabilityInternal.h>

#import <CoreFoundation/CFBase.h>

#ifndef kCFCoreFoundationVersionNumber_IOS_7_0
#define kCFCoreFoundationVersionNumber_IOS_7_0 838.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_7_1
#define kCFCoreFoundationVersionNumber_iOS_7_1 847.24
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1140.1
#endif

#ifndef __IPHONE_7_0
#define __IPHONE_7_0 70000
#endif

#ifndef __IPHONE_8_0
#define __IPHONE_8_0 80000
#endif

#ifndef AS_IOS8_SDK_OR_LATER
#define AS_IOS8_SDK_OR_LATER __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
#endif

#define AS_AT_LEAST_IOS7 (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_6_1)
#define AS_AT_LEAST_IOS7_1 (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_1)
#define AS_AT_LEAST_IOS8 (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0)
