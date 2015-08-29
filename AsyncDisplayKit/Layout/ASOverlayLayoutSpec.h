/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASLayoutSpec.h>

/**
 This layout spec lays out a single layoutable child and then overlays a layoutable object on top of it streched to its size
 */
@interface ASOverlayLayoutSpec : ASLayoutSpec

@property (nonatomic, strong) id<ASLayoutable> overlay;

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutable>)child overlay:(id<ASLayoutable>)overlay;

@end
