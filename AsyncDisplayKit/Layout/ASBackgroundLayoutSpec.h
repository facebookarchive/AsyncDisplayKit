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
 Lays out a single layoutable child, then lays out a background layoutable instance behind it stretched to its size.
 */
@interface ASBackgroundLayoutSpec : ASLayoutSpec

@property (nonatomic, strong) id<ASLayoutable> background;

/**
 @param child A child that is laid out to determine the size of this spec. If this is nil, then this method
        returns nil.
 @param background A layoutable object that is laid out behind the child. May be nil, in which case the background is omitted.
 */
+ (instancetype)backgroundLayoutSpecWithChild:(id<ASLayoutable>)child background:(id<ASLayoutable>)background;

@end
