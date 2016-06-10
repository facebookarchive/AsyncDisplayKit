//
//  UICollectionViewLayout+ASConvenience.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "UICollectionViewLayout+ASConvenience.h"

@implementation UICollectionViewLayout (ASConvenience)

- (BOOL)asdk_isFlowLayout
{
  return [self isKindOfClass:[UICollectionViewFlowLayout class]];
}

@end
