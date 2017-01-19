//
//  ASCollectionSectionController.h
//  Sample
//
//  Created by Adlai Holler on 12/29/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionSectionController : IGListSectionController

/**
 * The items managed by this section controller.
 */
@property (nonatomic, strong, readonly) NSArray<id<IGListDiffable>> *items;

- (void)setItems:(NSArray<id<IGListDiffable>> *)newItems
        animated:(BOOL)animated
      completion:(nullable void(^)())completion;

- (NSInteger)numberOfItems;

@end

NS_ASSUME_NONNULL_END
