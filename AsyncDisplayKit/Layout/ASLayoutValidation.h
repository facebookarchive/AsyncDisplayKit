//
//  ASLayoutValidation.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASLayout;

// Enable or disable automatic layout validation
#define LAYOUT_VALIDATION 0

ASDISPLAYNODE_EXTERN_C_BEGIN

extern void ASLayoutableValidateLayout(ASLayout *layout);

ASDISPLAYNODE_EXTERN_C_END

#pragma mark - ASLayoutableValidator

@protocol ASLayoutableValidator <NSObject>
- (void)validateLayout:(ASLayout *)layout;
@end

typedef void (^ASLayoutableBlockValidatorBlock)(id layout);

@interface ASLayoutableBlockValidator : NSObject<ASLayoutableValidator>
@property (nonatomic, copy) ASLayoutableBlockValidatorBlock block;
- (instancetype)initWithBlock:(ASLayoutableBlockValidatorBlock)block NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

/*
 * ASLayoutables that have sizeRange or layoutPosition set needs to be wrapped into a ASStaticLayoutSpec. This
 * validator checks if sublayouts has sizeRange or layoutPosition set and is wrapped in a ASStaticLayoutSpec
 */
@interface ASLayoutableStaticValidator : NSObject<ASLayoutableValidator>

@end

/*
 * ASLayoutables that have spacingBefore, spacingAfter, flexGrow, flexShrink, flexBasis, alignSelf, ascender or descender
 * set needs to be wrapped into a ASStackLayout. This validator checks if sublayouts has set one of this properties and
 * asserts if it's not wrapped in a ASStackLayout if so.
 */
@interface ASLayoutableStackValidator : NSObject<ASLayoutableValidator>

@end

/*
 * Not in use at the moment
 */
@interface ASLayoutablePreferredSizeValidator : NSObject<ASLayoutableValidator>

@end


#pragma mark - ASLayoutableValidation

@interface ASLayoutableValidation : NSObject

/// Currently registered validators
@property (copy, nonatomic, readonly) NSArray<id<ASLayoutableValidator>> *validators;

/// Start from given layout and validates each layout in the layout tree with registered validators
- (void)validateLayout:(ASLayout *)layout;

/// Register a layout validator
- (void)registerValidator:(id<ASLayoutableValidator>)validator;

/// Register a layout validator with a block. Method returns the registered ASLayoutableValidator object that can be used to store somewhere and unregister
- (id<ASLayoutableValidator>)registerValidatorWithBlock:(ASLayoutableBlockValidatorBlock)block;

/// Unregister a validtor
- (void)unregisterValidator:(id<ASLayoutableValidator>)validator;
@end

NS_ASSUME_NONNULL_END
