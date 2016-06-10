//
//  VideoModel.h
//  AsyncDisplayKit
//
//  Created by Erekle on 5/14/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@interface VideoModel : NSObject
@property (nonatomic, strong, readonly) NSString* title;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *userName;
@property (nonatomic, strong, readonly) NSURL *avatarUrl;
@end
