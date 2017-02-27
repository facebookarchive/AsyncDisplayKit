//
//  ASBlockTypes.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/25/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ASCellNode;

/**
 * ASCellNode creation block. Used to lazily create the ASCellNode instance for a specified indexPath.
 */
typedef ASCellNode * _Nonnull(^ASCellNodeBlock)();

// Type for the cancellation checker block passed into the async display blocks. YES means the operation has been cancelled, NO means continue.
typedef BOOL(^asdisplaynode_iscancelled_block_t)(void);
