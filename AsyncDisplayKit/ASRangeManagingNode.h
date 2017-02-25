//
//  ASRangeManagingNode.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Basically ASTableNode and ASCollectionNode.
 */
@protocol ASRangeManagingNode <NSObject>

/**
 * Registers this node to be informed of trait collection changes.
 * The node will not be retained.
 *
 * This is tricky business. Requirements:
 *  - Want to start getting trait before first measure (off-main)
 *  - Cannot miss trait collection changes
 *  -
 */
- (void)setTraitCollectionForNodeAndRegisterForUpdates:(ASCellNode *)node;

@end

NS_ASSUME_NONNULL_END

#define ASRangeManagingNodeSetTraitCollectionForNodeAndRegisterUpdates(traitsLock, cellNodes) \
- (void)setTraitCollectionForNodeAndRegisterForUpdates:(ASCellNode *)node\
{ \
  /* Register first, so we can't miss any updates. */ \
  traitsLock.lock();\
    [cellNodes addObject:node];\
  traitsLock.unlock();\
  \
  ASTraitCollectionPropagateDown(node, self.primitiveTraitCollection);\
}
