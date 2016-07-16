//
//  ASLayoutSpec+Private.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutSpec.h"

#import <objc/runtime.h>
#import <vector>
#import <map>

typedef std::map<unsigned long, id<ASLayoutable>, std::less<unsigned long>> ASChildrenMap;

@interface ASLayoutSpec (Private)

/*
 * Inside ASDK the childrenMap property should be preferred over the children array to prevent unecessary boxing
 */
@property (nonatomic, assign, readonly) ASChildrenMap childrenMap;

@end
