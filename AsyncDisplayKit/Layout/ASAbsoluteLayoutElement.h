//
//  ASAbsoluteLayoutElement.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

NS_ASSUME_NONNULL_BEGIN

/**
 *  Layout options that can be defined for an ASLayoutElement being added to a ASAbsoluteLayoutSpec.
 */
@protocol ASAbsoluteLayoutElement

/**
 * @abstract The position of this object within its parent spec.
 */
@property (nonatomic, assign) CGPoint layoutPosition;


#pragma mark Deprecated

@property (nonatomic, assign) ASRelativeSizeRange sizeRange ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END
