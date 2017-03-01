//
//  ASDataController+Beta.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASDataController.h>

@class ASDataControllerLayoutContext, ASElementMap;

NS_ASSUME_NONNULL_BEGIN

@protocol ASDataControllerLayoutDelegate <NSObject>

/**
 * @abstract Returns a layout context for given element map that will be used to prepare a new layout. 
 * The context should return the element map and any additional information needed for the coming layout pass.
 *
 * @discussion This method will be called on main thread.
 */
- (ASDataControllerLayoutContext *)layoutContextWithElementMap:(ASElementMap *)map;

/**
 * @abstract Prepares in advance a new layout for given context.
 *
 * @param context A context that was previously returned by `-layoutContextWithElementMap:`. It contains all elements to be laid out and any additional information needed.
 *
 * @discussion This method is called ahead of time, i.e before the underlying collection/table view is aware of the provided elements.
 * As a result, this method should rely solely on the given context and should not reach out to its collection/table view for information regarding items.
 *
 * @discussion This method will be called on background theads. It must be thread-safe and should not change any internal state of the conforming object.
 * It's recommended to put the resulting layouts of this method into a thread-safe cache that can be looked up later on.
 */
- (void)prepareLayoutForLayoutContext:(ASDataControllerLayoutContext *)context;

@end

@interface ASDataController ()

/**
 * Delegate for preparing layouts. Main thead only.
 */
@property (nonatomic, weak) id<ASDataControllerLayoutDelegate> layoutDelegate;

@end

NS_ASSUME_NONNULL_END
