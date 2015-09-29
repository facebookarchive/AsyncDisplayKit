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

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section;

@end

@interface ASCollectionViewFlowLayoutInspector : NSObject <ASCollectionViewLayoutInspecting>

@property (nonatomic, weak) ASCollectionView *collectionView;
@property (nonatomic, weak) UICollectionViewFlowLayout *layout;

- (ASSizeRange)collectionView:(ASCollectionView *)collectionView constrainedSizeForSupplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView numberOfSectionsForSupplementaryKind:(NSString *)kind;

- (NSUInteger)collectionView:(ASCollectionView *)collectionView supplementaryViewsOfKind:(NSString *)kind inSection:(NSUInteger)section;

@end
