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
 * Begins measurement of the cell node, if it hasn't already begun.
 */
- (void)beginMeasuringNode;

/**
 * The cell node created by this context. Begins and waits for measurement if needed.
 */
@property (atomic, readonly, strong) ASCellNode *node;

/**
 * The node, if measurement has already completed.
 */
@property (atomic, readonly, nullable, strong) ASCellNode *nodeIfMeasured;

+ (NSArray<NSIndexPath *> *)indexPathsFromContexts:(NSArray<ASIndexedNodeContext *> *)contexts;

@end

NS_ASSUME_NONNULL_END
