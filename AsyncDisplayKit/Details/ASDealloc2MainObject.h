/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>


/**
 * _OBJC_SUPPORTED_INLINE_REFCNT_WITH_DEALLOC2MAIN permits classes to implement their own reference counting and enforce
 * deallocation on the main thread, but requires manual reference counting.  This superclass exposes such functionality
 * to ARC-enabled classes.
 */
@interface ASDealloc2MainObject : NSObject

- (BOOL)_isDeallocating;

@end
