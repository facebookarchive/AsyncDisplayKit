//
//  ASCollectionLayoutDelegate.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ASElementMap, ASCollectionLayoutContext, ASCollectionLayoutState;

NS_ASSUME_NONNULL_BEGIN

@protocol ASCollectionLayoutDelegate <NSObject>

/**
 * @abstract Returns any additional information needed for a coming layout pass with the given elements.
 *
 * @discussion The returned object must support equality and hashing (i.e `-isEqual:` and `-hash` must be properly implemented).
 *
 * @discussion This method will be called on main thread.
 */
- (nullable id)additionalInfoForLayoutWithElements:(ASElementMap *)elements;

/**
 * @abstract Prepares and returns a new layout for given context.
 *
 * @param context A context that contains all elements to be laid out and any additional information needed.
 *
 * @return The new layout calculated for the given context.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, this method should rely solely on the given context and should not reach out to other objects for information not available in the context.
 *
 * @discussion This method will be called on background theads. It must be thread-safe and should not change any internal state of this object.
 *
 * @discussion This method must block its calling thread. It can dispatch to other theads to reduce blocking time.
 */
- (ASCollectionLayoutState *)calculateLayoutWithContext:(ASCollectionLayoutContext *)context;

@end

NS_ASSUME_NONNULL_END
