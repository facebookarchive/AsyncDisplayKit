//
//  ASMainSerialQueue.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 12/11/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASMainSerialQueue : NSObject

- (void)performBlockOnMainThread:(dispatch_block_t)block;

@end
