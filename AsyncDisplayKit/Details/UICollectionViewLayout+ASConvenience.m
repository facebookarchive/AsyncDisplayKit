//
//  UICollectionViewLayout+ASConvenience.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/UICollectionViewLayout+ASConvenience.h>

#import <UIKit/UICollectionViewFlowLayout.h>

#import <AsyncDisplayKit/ASCollectionViewFlowLayoutInspector.h>

@implementation UICollectionViewLayout (ASLayoutInspectorProviding)

- (id<ASCollectionViewLayoutInspecting>)asdk_layoutInspector
{
  UICollectionViewFlowLayout *flow = ASDynamicCast(self, UICollectionViewFlowLayout);
  if (flow != nil) {
    return [[ASCollectionViewFlowLayoutInspector alloc] initWithFlowLayout:flow];
  } else {
    return [[ASCollectionViewLayoutInspector alloc] init];
  }
}

@end
