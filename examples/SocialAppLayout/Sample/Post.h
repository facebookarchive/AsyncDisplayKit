//
//  Post.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@interface Post : NSObject

@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *photo;
@property (nonatomic, copy) NSString *post;
@property (nonatomic, copy) NSString *time;
@property (nonatomic, copy) NSString *media;
@property (nonatomic, assign) NSInteger via;

@property (nonatomic, assign) NSInteger likes;
@property (nonatomic, assign) NSInteger comments;

@end
