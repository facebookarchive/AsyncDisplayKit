/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import "CKTextKitRenderer.h"

/**
 Application extensions to NSTextCheckingType. We're allowed to do this (see NSTextCheckingAllCustomTypes).
 */
static uint64_t const CKTextKitTextCheckingTypeEntity =               1ULL << 33;
static uint64_t const CKTextKitTextCheckingTypeTruncation =           1ULL << 34;

@class CKTextKitEntityAttribute;

@interface CKTextKitTextCheckingResult : NSTextCheckingResult
@property (nonatomic, strong, readonly) CKTextKitEntityAttribute *entityAttribute;
@end

@interface CKTextKitRenderer (TextChecking)

- (NSTextCheckingResult *)textCheckingResultAtPoint:(CGPoint)point;

@end
