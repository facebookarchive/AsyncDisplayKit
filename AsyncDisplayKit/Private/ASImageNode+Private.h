//
//  ASImageNode+Private.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma mark - ASImageNode

#import "ASImageNode.h"

@interface ASImageNode (Private)

/*
 * Set the image property of the ASImageNode. Subclasses like ASNetworkImageNode do not allow setting the
 * image property directly and throw an assertion. There still needs to be a way for subclasses of
 * ASNetworkImageNode to set the image.
 *
 * This is exposed to library subclasses, i.e. ASNetworkImageNode, ASMultiplexImageNode and ASVideoNode for setting
 * the image directly without going throug the setter of the superclass
 */
- (void)__setImage:(UIImage *)image;

@end
