//
//  ASTextNode+Beta.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/25/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/ASTextNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASTextNode ()

/**
 @abstract An array of descending scale factors that will be applied to this text node to try to make it fit within its constrained size
 @discussion This array should be in descending order and NOT contain the scale factor 1.0. For example, it could return @[@(.9), @(.85), @(.8)];
 @default nil (no scaling)
 */
@property (nullable, nonatomic, copy) NSArray<NSNumber *> *pointSizeScaleFactors;

/**
 @abstract Text margins for text laid out in the text node.
 @discussion defaults to UIEdgeInsetsZero.
 This property can be useful for handling text which does not fit within the view by default. An example: like UILabel,
 ASTextNode will clip the left and right of the string "judar" if it's rendered in an italicised font.
 */
@property (nonatomic, assign) UIEdgeInsets textContainerInset;

@end

NS_ASSUME_NONNULL_END
