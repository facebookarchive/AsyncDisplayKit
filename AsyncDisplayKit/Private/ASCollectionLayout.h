//
//  ASCollectionLayout.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/21/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UICollectionViewLayout.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

@class ASLayout, ASCollectionElement, ASElementMap, ASRectTable<KeyType>;

/**
 * An immutable object representing a snapshot of the state of a layout,
 * designed for driving UICollectionViewLayout.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASCollectionLayout : NSObject <NSCopying>

- (instancetype)initWithMap:(ASElementMap *)map
                       size:(CGSize)contentSize
                     frames:(ASRectTable<ASCollectionElement *> *)frames;

#pragma mark - UICollectionViewLayout Methods

@property (nonatomic, readonly) CGSize collectionViewContentSize;

- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect;

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;

- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
