//
//  ASRelativeLayoutSpec.h
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 12/31/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASRelativeLayoutDefines.h>

NS_ASSUME_NONNULL_BEGIN

/** Lays out a single layoutable child and positions it within the layout bounds according to vertical and horizontal positional specifiers.
 *  Can position the child at any of the 4 corners, or the middle of any of the 4 edges, as well as the center - similar to "9-part" image areas.
 */
@interface ASRelativeLayoutSpec : ASLayoutSpec

// You may create a spec with alloc / init, then set any non-default properties; or use a convenience initialize that accepts all properties.
@property (nonatomic, assign) ASRelativeLayoutSpecPosition horizontalPosition;
@property (nonatomic, assign) ASRelativeLayoutSpecPosition verticalPosition;
@property (nonatomic, assign) ASRelativeLayoutSpecSizingOption sizingOption;

/*!
 * @discussion convenience constructor for a ASRelativeLayoutSpec
 * @param horizontalPosition how to position the item on the horizontal (x) axis
 * @param verticalPosition how to position the item on the vertical (y) axis
 * @param sizingOption how much size to take up
 * @param child the child to layout
 * @return a configured ASRelativeLayoutSpec
 */
+ (instancetype)relativePositionLayoutSpecWithHorizontalPosition:(ASRelativeLayoutSpecPosition)horizontalPosition
                                                verticalPosition:(ASRelativeLayoutSpecPosition)verticalPosition
                                                    sizingOption:(ASRelativeLayoutSpecSizingOption)sizingOption
                                                           child:(id<ASLayoutable>)child;

/*!
 * @discussion convenience initializer for a ASRelativeLayoutSpec
 * @param horizontalPosition how to position the item on the horizontal (x) axis
 * @param verticalPosition how to position the item on the vertical (y) axis
 * @param sizingOption how much size to take up
 * @param child the child to layout
 * @return a configured ASRelativeLayoutSpec
 */
- (instancetype)initWithHorizontalPosition:(ASRelativeLayoutSpecPosition)horizontalPosition
                          verticalPosition:(ASRelativeLayoutSpecPosition)verticalPosition
                              sizingOption:(ASRelativeLayoutSpecSizingOption)sizingOption
                                     child:(id<ASLayoutable>)child;

@end

NS_ASSUME_NONNULL_END

