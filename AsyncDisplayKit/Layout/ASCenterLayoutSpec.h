//
//  ASCenterLayoutSpec.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASRelativeLayoutSpec.h>
#import <AsyncDisplayKit/ASCenterLayoutDefines.h>


NS_ASSUME_NONNULL_BEGIN

/** Lays out a single layoutable child and position it so that it is centered into the layout bounds.
  * NOTE: ASRelativeLayoutSpec offers all of the capabilities of Center, and more.
  * Check it out if you would like to be able to position the child at any corner or the middle of an edge.
 */
@interface ASCenterLayoutSpec : ASRelativeLayoutSpec

@property (nonatomic, assign) ASCenterLayoutSpecCenteringOptions centeringOptions;
@property (nonatomic, assign) ASCenterLayoutSpecSizingOptions sizingOptions;

/**
 * Initializer.
 *
 * @param centeringOptions How the child is centered.
 *
 * @param sizingOptions How much space will be taken up.
 *
 * @param child The child to center.
 */
+ (instancetype)centerLayoutSpecWithCenteringOptions:(ASCenterLayoutSpecCenteringOptions)centeringOptions
                                       sizingOptions:(ASCenterLayoutSpecSizingOptions)sizingOptions
                                               child:(id<ASLayoutable>)child;

@end

NS_ASSUME_NONNULL_END
