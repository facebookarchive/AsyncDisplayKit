//
//  ASOverlayLayoutSpec.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASLayoutSpec.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This layout spec lays out a single layoutable child and then overlays a layoutable object on top of it streched to its size
 */
@interface ASOverlayLayoutSpec : ASLayoutSpec

/**
 * Overlay layoutable of this layout spec
 */
@property (nullable, nonatomic, strong) id<ASLayoutable> overlay;

/**
 * Creates and returns an ASOverlayLayoutSpec object with a given child and an layoutable that act as overlay.
 *
 * @param child A child that is laid out to determine the size of this spec.
 * @param overlay A layoutable object that is laid out over the child. If this is nil, the overlay is omitted.
 */
+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutable>)child overlay:(nullable id<ASLayoutable>)overlay;

@end

NS_ASSUME_NONNULL_END
