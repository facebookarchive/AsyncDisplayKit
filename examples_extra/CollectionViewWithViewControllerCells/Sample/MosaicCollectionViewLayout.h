//
//  MosaicCollectionViewLayout.h
//  Sample
//
//  Created by McCallum, Levi on 11/22/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
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