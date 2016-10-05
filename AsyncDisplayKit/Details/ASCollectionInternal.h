//
//  ASCollectionInternal.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 1/1/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASCollectionView.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionViewLayoutFacilitatorProtocol;
@class ASCollectionNode;
@class ASDataController;
@class ASRangeController;

@interface ASCollectionView ()
- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator;

@property (nonatomic, weak, readwrite) ASCollectionNode *collectionNode;
@property (nonatomic, strong, readonly) ASDataController *dataController;
@property (nonatomic, strong, readonly) ASRangeController *rangeController;
@end

NS_ASSUME_NONNULL_END
