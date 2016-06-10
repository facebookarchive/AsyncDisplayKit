//
//  LoadingNode.h
//  AsyncDisplayKit
//
//  Created by Samuel Stow on 1/9/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LoadingNode : ASCellNode

+ (CGFloat)desiredHeightForWidth:(CGFloat)width;

@end
