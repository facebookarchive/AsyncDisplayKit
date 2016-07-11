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

@interface ASIndexedNodeContext : NSObject

@property (nonatomic, readonly, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly, assign) ASSizeRange constrainedSize;
@property (nonatomic, readonly, assign) ASEnvironmentTraitCollection environmentTraitCollection;

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize
       environmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection;

/**
 * Returns a node allocated by executing node block. Node block will be nil out immediately.
 */
- (ASCellNode *)allocateNode;

@end
