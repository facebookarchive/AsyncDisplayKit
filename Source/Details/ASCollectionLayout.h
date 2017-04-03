//
//  ASCollectionLayout.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/2/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ASElementMap, ASCollectionLayout, ASCollectionNode;

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionLayoutDataSource <NSObject>

/**
 * Current element map that can be used by the collection layout, usually the visible map that is in the "UIKit index space."
 *
 * @discussion This method is always called on main.
 */
- (ASElementMap *)elementMapForCollectionLayout:(ASCollectionLayout *)collectionLayout;

@end

@interface ASCollectionLayout : UICollectionViewLayout

@property (nonatomic, weak) id<ASCollectionLayoutDataSource> dataSource;

/**
 * The collection node object currently using this layout object.
 *
 * @discussion The collection node object sets the value of this property when a new layout object is assigned to it.
 *
 * @discussion To get the truth on the current state of the collection, call methods on the collection node or the data source rather than the collection view because:
 *  1. The view might not yet be allocated.
 *  2. The collection node and data source are thread-safe.
 */
@property (nonatomic, weak) ASCollectionNode *collectionNode;

- (instancetype)initWithCoder:(NSCoder *)aDecoder __unavailable;

@end

NS_ASSUME_NONNULL_END
