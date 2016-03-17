//
//  ASIndexedNodeContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 2/28/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDataController.h>

@interface ASIndexedNodeContext : NSObject

@property (nonatomic, readonly, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly, assign) ASSizeRange constrainedSize;

- (instancetype)initWithNodeBlock:(ASCellNodeBlock)nodeBlock
                        indexPath:(NSIndexPath *)indexPath
                  constrainedSize:(ASSizeRange)constrainedSize;

/**
 * Returns a node allocated by executing node block. Node block will be nil out immediately.
 */
- (ASCellNode *)allocateNode;

@end
