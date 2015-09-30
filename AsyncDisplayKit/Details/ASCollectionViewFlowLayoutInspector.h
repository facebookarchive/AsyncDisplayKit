//
//  ASCollectionViewFlowLayoutInspector.h
//  Pods
//
//  Created by Levi McCallum on 9/29/15.
//
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASDimension.h>

@class ASCollectionView;

@protocol ASCollectionViewLayoutInspecting <NSObject>

/**
 * Asks the inspector 
 */
- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

/**
 * Asks the inspector for the number of supplementary sections in the collection view for the given kind.
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind;

/**
 * Asks the inspector for the number of supplementary views for the given kind in the specified section.
 */
- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section;

@end

@interface ASCollectionViewFlowLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@property (nonatomic, weak) ASCollectionView *collectionView;
@property (nonatomic, weak) UICollectionViewFlowLayout *layout;

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section;

@end
