//
//  ASCollectionNode+Beta.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASCollectionNode.h"
@protocol ASCollectionViewLayoutFacilitatorProtocol;

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionNode (Beta)

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(nullable id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator;

- (void)beginUpdates ASDISPLAYNODE_DEPRECATED;

- (void)endUpdatesAnimated:(BOOL)animated ASDISPLAYNODE_DEPRECATED;

- (void)endUpdatesAnimated:(BOOL)animated completion:(nullable void (^)(BOOL))completion ASDISPLAYNODE_DEPRECATED;

@end

NS_ASSUME_NONNULL_END
