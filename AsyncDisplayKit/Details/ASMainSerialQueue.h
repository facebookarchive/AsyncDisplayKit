//
//  ASMainSerialQueue.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 12/11/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@interface ASMainSerialQueue : NSObject

- (void)performBlockOnMainThread:(dispatch_block_t)block;

@end
