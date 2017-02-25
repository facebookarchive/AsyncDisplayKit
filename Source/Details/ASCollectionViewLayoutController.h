//
//  ASCollectionViewLayoutController.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASAbstractLayoutController.h>

NS_ASSUME_NONNULL_BEGIN

@class ASCollectionView;

AS_SUBCLASSING_RESTRICTED
@interface ASCollectionViewLayoutController : ASAbstractLayoutController

- (instancetype)initWithCollectionView:(ASCollectionView *)collectionView;

@end

NS_ASSUME_NONNULL_END
