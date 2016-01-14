//
//  ASCollectionViewLayoutFacilitatorProtocol.h
//  Pods
//
//  Created by Bin Liu on 1/13/16.
//
//

#ifndef ASCollectionViewLayoutFacilitatorProtocol_h
#define ASCollectionViewLayoutFacilitatorProtocol_h

@protocol ASCollectionViewLayoutFacilitatorProtocol <NSObject>

- (void)collectionViewInsertingCellAtIndexPaths:(NSArray *)indexPaths;
- (void)collectionViewInsertingSectionsAtIndexSet:(NSIndexSet *)indexes;
- (void)collectionViewDeletingSectionsAtIndexSet:(NSIndexSet *)indexes;

@end

#endif /* ASCollectionViewLayoutFacilitatorProtocol_h */
