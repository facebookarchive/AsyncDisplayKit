//
//  BlurbNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * Simple node that displays a placekitten.com attribution.
 */
@interface BlurbNode : ASCellNode

+ (CGFloat)desiredHeightForWidth:(CGFloat)width;

@end
