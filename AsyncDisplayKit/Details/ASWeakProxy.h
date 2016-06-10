//
//  ASWeakProxy.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/12/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@interface ASWeakProxy : NSObject

@property (nonatomic, weak, readonly) id target;

+ (instancetype)weakProxyWithTarget:(id)target;

@end
