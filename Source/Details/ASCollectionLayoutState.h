//
//  ASCollectionLayoutState.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 9/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASElementMap, ASCollectionElement, ASLayout;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASCollectionLayoutState : NSObject

/// The elements used to calculate this object
@property (nonatomic, strong, readonly) ASElementMap *elements;

@property (nonatomic, assign, readonly) CGSize contentSize;

/// Element to layout attributes map. Should use weak pointers for elements.
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *elementToLayoutArrtibutesMap;

- (instancetype)init __unavailable;

/**
 * Designated initializer.
 *
 * @param elements The elements used to calculate this object
 *
 * @param contentSize The content size of the collection's layout
 *
 * @param elementToLayoutArrtibutesMap Map between elements to their layout attributes. The map may contain all elements, or a subset of them and will be updated later. 
 * Also, it should have NSMapTableObjectPointerPersonality and NSMapTableWeakMemory as key options.
 */
- (instancetype)initWithElements:(ASElementMap *)elements contentSize:(CGSize)contentSize elementToLayoutArrtibutesMap:(NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)attrsMap NS_DESIGNATED_INITIALIZER;

/**
 * Convenience initializer.
 *
 * @param elements The elements used to calculate this object
 *
 * @param layout The layout describes size and position of all elements, or a subset of them and will be updated later.
 *
 * @discussion The sublayouts that describe position of elements must be direct children of the root layout object parameter.
 */
- (instancetype)initWithElements:(ASElementMap *)elements layout:(ASLayout *)layout;

@end

NS_ASSUME_NONNULL_END
