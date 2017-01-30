//
//  _ASCollectionViewCell.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/30/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ASCellNode;

@interface _ASCollectionViewCell : UICollectionViewCell
@property (nonatomic, weak) ASCellNode *node;
@property (nonatomic, strong) UICollectionViewLayoutAttributes *layoutAttributes;
@end

