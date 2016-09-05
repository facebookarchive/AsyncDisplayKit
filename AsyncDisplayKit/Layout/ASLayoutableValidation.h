//
//  ASLayoutableValidation.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

// Enable or disable automatic layout validation
#define LAYOUT_VALIDATION 1

NS_ASSUME_NONNULL_BEGIN

@protocol ASLayoutable;

extern NSString * const ASLayoutableValidationErrorDomain;

typedef BOOL (^ASLayoutableValidationBlock)(id<ASLayoutable> layoutable, NSError * __autoreleasing *error);

ASDISPLAYNODE_EXTERN_C_BEGIN

/*
 * Returns a layoutable validation block that rejects ASStackLayoutables
 */
extern ASLayoutableValidationBlock ASLayoutableValidatorBlockRejectStackLayoutable();

/*
 * Returns a layoutable validation block that rejects ASStaticLayoutables
 */
extern ASLayoutableValidationBlock ASLayoutableValidatorBlockRejectStaticLayoutable();

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END
