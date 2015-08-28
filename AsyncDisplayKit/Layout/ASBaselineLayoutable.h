/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

@protocol ASBaselineLayoutable

/**
 * @abstract The distance from the top of the layoutable object to its baseline
 */
@property (nonatomic, readwrite) CGFloat ascender;

/**
 * @abstract The distance from the bottom of the layoutable object to its baseline
 */
@property (nonatomic, readwrite) CGFloat descender;

@end
