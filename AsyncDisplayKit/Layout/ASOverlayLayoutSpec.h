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
 This layout spec lays out a single layoutElement child and then overlays a layoutElement object on top of it streched to its size
 */
@interface ASOverlayLayoutSpec : ASLayoutSpec

@property (nullable, nonatomic, strong) id<ASLayoutElement> overlay;

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutElement>)child overlay:(nullable id<ASLayoutElement>)overlay;

@end

NS_ASSUME_NONNULL_END
