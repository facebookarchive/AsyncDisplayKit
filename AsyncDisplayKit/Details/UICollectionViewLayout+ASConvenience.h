//
//  UICollectionViewLayout+ASConvenience.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UICollectionViewLayout.h>

@protocol ASCollectionViewLayoutInspecting;

NS_ASSUME_NONNULL_BEGIN

@interface UICollectionViewLayout (ASLayoutInspectorProviding)

/**
 * You can override this method on your @c UICollectionViewLayout subclass to
 * return a layout inspector tailored to your layout.
 *
 * It's fine to return @c self. You must not return @c nil.
 */
- (id<ASCollectionViewLayoutInspecting>)asdk_layoutInspector;

@end

NS_ASSUME_NONNULL_END
