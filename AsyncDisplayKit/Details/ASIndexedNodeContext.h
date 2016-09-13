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

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection;

@property (nonatomic, readonly, strong) NSIndexPath *indexPath;

/**
 * The node created by `nodeCreationOperation`. This will be nil until the operation is finished.
 */
@property (atomic, readonly, nullable, strong) ASCellNode *node;

/**
 * An operation to allocate and measure the node.
 */
@property (nonatomic, readonly, strong) NSBlockOperation *nodeCreationOperation;

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts;

@end

NS_ASSUME_NONNULL_END
