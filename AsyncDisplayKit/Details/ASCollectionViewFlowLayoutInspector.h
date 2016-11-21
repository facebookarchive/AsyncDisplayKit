//
//  ASCollectionViewFlowLayoutInspector.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#pragma once

#include "ASCollectionViewLayoutInspector.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A layout inspector implementation specific for the sizing behavior of UICollectionViewFlowLayouts
 */
@interface ASCollectionViewFlowLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@property (nonatomic, weak, readonly) UICollectionViewFlowLayout *layout;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView flowLayout:(UICollectionViewFlowLayout *)flowLayout NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
