//
//  ASCollectionInternal.h
//  AsyncDisplayKit
//
//  Created by Scott Goodson on 1/1/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASCollectionView.h"
#import "ASCollectionNode.h"
#import "ASDataController.h"
#import "ASRangeController.h"

@interface ASCollectionView ()
- (instancetype)_initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout layoutFacilitator:(id<ASCollectionViewLayoutFacilitatorProtocol>)layoutFacilitator ownedByNode:(BOOL)ownedByNode;

@property (nonatomic, weak, readwrite) ASCollectionNode *collectionNode;
@property (nonatomic, strong, readonly) ASDataController *dataController;
@property (nonatomic, strong, readonly) ASRangeController *rangeController;
@end
