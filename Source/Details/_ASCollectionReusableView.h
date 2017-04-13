//
//  _ASCollectionReusableView.h
//  AsyncDisplayKit
//
//  Created by Phil Larson on 4/10/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASCellNode;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface _ASCollectionReusableView : UICollectionReusableView
@property (nonatomic, weak) ASCellNode *node;
@property (nonatomic, strong, nullable) UICollectionViewLayoutAttributes *layoutAttributes;
@end

NS_ASSUME_NONNULL_END
