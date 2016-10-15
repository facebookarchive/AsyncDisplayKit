//
//  ASIndexedNodeContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDataController.h>
#import <AsyncDisplayKit/ASEnvironment.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASIndexedNodeContext : NSObject

/**
 * The index path at which this node was originally inserted. Don't rely on this
 * property too heavily – we should remove it in the future.
 */
@property (nonatomic, readonly, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly, copy, nullable) NSString *supplementaryElementKind;
@property (nonatomic, readonly, assign) ASSizeRange constrainedSize;
@property (nonatomic, readonly, assign) ASEnvironmentTraitCollection environmentTraitCollection;

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
         supplementaryElementKind:(nullable NSString *)supplementaryElementKind
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection;

/**
 * @return The node, running the node block if necessary. The node block will be discarded
 * after the first time it is run.
 */
@property (strong, readonly) ASCellNode *node;

/**
 * @return The node, if the node block has been run already.
 */
@property (strong, readonly, nullable) ASCellNode *nodeIfAllocated;

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts;

@end

NS_ASSUME_NONNULL_END
