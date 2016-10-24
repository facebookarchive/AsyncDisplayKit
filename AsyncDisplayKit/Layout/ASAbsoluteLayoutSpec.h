//
//  ASAbsoluteLayoutSpec.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

/** How much space the spec will take up. */
typedef NS_ENUM(NSInteger, ASAbsoluteLayoutSpecSizing) {
  /** The spec will take up the maximum size possible. */
  ASAbsoluteLayoutSpecSizingDefault,
  /** Computes a size for the spec that is the union of all childrens' frames. */
  ASAbsoluteLayoutSpecSizingSizeToFit,
};

NS_ASSUME_NONNULL_BEGIN

/**
 A layout spec that positions children at fixed positions.
 */
@interface ASAbsoluteLayoutSpec : ASLayoutSpec

/**
 How much space will the spec taken up
 */
@property (nonatomic, assign) ASAbsoluteLayoutSpecSizing sizing;

/**
 @param sizing How much space the spec will take up
 @param children Children to be positioned at fixed positions
 */
+ (instancetype)absoluteLayoutSpecWithSizing:(ASAbsoluteLayoutSpecSizing)sizing children:(NSArray<id<ASLayoutElement>> *)children AS_WARN_UNUSED_RESULT;

/**
 @param children Children to be positioned at fixed positions
 */
+ (instancetype)absoluteLayoutSpecWithChildren:(NSArray<id<ASLayoutElement>> *)children AS_WARN_UNUSED_RESULT;

@end


#pragma mark - Deprecated

@interface ASStaticLayoutSpec : ASAbsoluteLayoutSpec

+ (instancetype)staticLayoutSpecWithChildren:(NSArray<id<ASLayoutElement>> *)children AS_WARN_UNUSED_RESULT ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END
