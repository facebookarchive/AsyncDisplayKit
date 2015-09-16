//
//  ASCollectionNode.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 9/5/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * ASCollectionNode is a node based class that wraps an ASCollectionView. It can be used
 * as a subnode of another node, and provide room for many (great) features and improvements later on.
 */
@interface ASCollectionNode : ASDisplayNode

- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) ASCollectionView *view;

@end
