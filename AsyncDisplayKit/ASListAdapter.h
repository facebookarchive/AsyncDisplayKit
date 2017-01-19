//
//  ASListAdapter.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/19/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASSectionController;
@class ASCollectionNode;

@protocol ASListAdapter <NSObject>

/**
 * The collection node associated with the data adapter.
 *
 * This will be called by ASDK when you set the data adapter on the
 * collection node.
 */
@property (nonatomic, weak) ASCollectionNode *collectionNode;

/**
 * Asks the list adapter for the number of sections.
 *
 * @return The number of sections.
 */
- (NSInteger)numberOfSections;

/**
 * Asks the list adapter to provide the section controller for a given section.
 *
 * @param section The section index.
 *
 * @return The section controller.
 */
- (id<ASSectionController>)sectionControllerForSection:(NSInteger)section;

@end

NS_ASSUME_NONNULL_END
