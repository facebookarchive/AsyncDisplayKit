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

@class ASElementMap, ASCollectionElement;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASCollectionLayoutState : NSObject

/// The element map used to calculate this object
@property (nonatomic, weak, readonly) ASElementMap *elementMap;

@property (nonatomic, assign, readonly) CGSize contentSize;
/// Element to layout attributes map. Should use weak pointers for elements.
@property (nonatomic, strong, readonly) NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *elementToLayoutArrtibutesMap;

- (instancetype)init __unavailable;

/**
 * Designated initializer.
 *
 * @param elementMap The element map used to calculate this object
 *
 * @param contentSize The content size of the collection's layout
 *
 * @param elementToLayoutArrtibutesMap Map between elements to their layout attributes. The map may contain all elements, or a subset of them and to be updated later. Should use weak pointers for elements.
 */
- (instancetype)initWithElementMap:(ASElementMap *)elementMap contentSize:(CGSize)contentSize elementToLayoutArrtibutesMap:(NSMapTable<ASCollectionElement *, UICollectionViewLayoutAttributes *> *)attrsMap NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
