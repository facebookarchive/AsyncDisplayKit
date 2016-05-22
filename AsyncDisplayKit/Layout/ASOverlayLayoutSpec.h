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

NS_ASSUME_NONNULL_BEGIN

/**
 This layout spec lays out a single layout producer child and then overlays a layout producer object on top of it streched to its size
 */
@interface ASOverlayLayoutSpec : ASLayoutSpec

@property (nullable, nonatomic, strong) id<ASLayoutProducer> overlay;

+ (instancetype)overlayLayoutSpecWithChild:(id<ASLayoutProducer>)child overlay:(nullable id<ASLayoutProducer>)overlay;

@end

NS_ASSUME_NONNULL_END
