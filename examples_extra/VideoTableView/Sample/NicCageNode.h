//
//  NicCageNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * Social media-style node that displays a kitten picture and a random length
 * of lorem ipsum text.  Uses a placekitten.com kitten of the specified size.
 */
@interface NicCageNode : ASCellNode

- (instancetype)initWithKittenOfSize:(CGSize)size;

- (void)toggleImageEnlargement;

@end
