//
//  ASSupplementaryNodeSource.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBlockTypes.h>
#import <AsyncDisplayKit/ASDimension.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASSupplementaryNodeSource <NSObject>

/**
 * A method to provide the node-block for the supplementary element.
 *
 * @param elementKind The kind of supplementary element.
 * @param index The index of the item.
 * @return A node block for the supplementary element.
 * @see collectionNode:nodeForSupplementaryElementOfKind:atIndexPath:
 */
- (ASCellNodeBlock)nodeBlockForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index;

@optional

/**
 * A method to provide the size range used for measuring the supplementary
 * element of the given kind at the given index.
 *
 * @param elementKind The kind of supplementary element.
 * @param index The index of the item.
 * @return A size range used for asynchronously measuring the node.
 * @see collectionNode:constrainedSizeForSupplementaryElementOfKind:atIndexPath:
 */
- (ASSizeRange)sizeRangeForSupplementaryElementOfKind:(NSString *)elementKind atIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
