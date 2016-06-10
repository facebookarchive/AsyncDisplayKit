//
//  MosaicCollectionViewLayout.h
//  AsyncDisplayKit
//
//  Created by McCallum, Levi on 11/22/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface MosaicCollectionViewLayout : UICollectionViewLayout

@property (assign, nonatomic) NSUInteger numberOfColumns;
@property (assign, nonatomic) CGFloat columnSpacing;
@property (assign, nonatomic) UIEdgeInsets sectionInset;
@property (assign, nonatomic) UIEdgeInsets interItemSpacing;
@property (assign, nonatomic) CGFloat headerHeight;

@end

@protocol MosaicCollectionViewLayoutDelegate <ASCollectionViewDelegate>

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(MosaicCollectionViewLayout *)layout originalItemSizeAtIndexPath:(NSIndexPath *)indexPath;

@end

@interface MosaicCollectionViewLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@end
