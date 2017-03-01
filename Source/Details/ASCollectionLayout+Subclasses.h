//
//  ASCollectionLayoutSubclasses.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayout.h>
#import <AsyncDisplayKit/ASDataController+Beta.h>

@class ASCollectionContentAttributes;

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionLayout () <ASDataControllerLayoutDelegate>

/// The current content, if any. This property must be accessed on main thread.
@property (nonatomic, strong, nullable) ASCollectionContentAttributes *currentContentAttributes;

/**
 * @abstract Prepares and returns a new layout for given context.
 *
 * @param context A context that was previously returned by `-layoutContextWithElementMap:`. It contains all elements to be laid out and any additional information needed.
 *
 * @return The new layout calculated for the given context.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, this method should rely solely on the given context and should not reach out to its collection/table view for information regarding items.
 *
 * @discussion This method will be called on background theads. It must be thread-safe and should not change any internal state of the layout object.
 *
 * @discussion This method must block its calling thread but can dispatch to other theads to reduce blocking time.
 */
- (ASCollectionContentAttributes *)calculateLayoutForLayoutContext:(ASDataControllerLayoutContext *)context;

@end

NS_ASSUME_NONNULL_END
