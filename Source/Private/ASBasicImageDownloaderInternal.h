//
//  ASBasicImageDownloaderInternal.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

@interface ASBasicImageDownloaderContext : NSObject

+ (ASBasicImageDownloaderContext *)contextForURL:(NSURL *)URL;

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, weak) NSURLSessionTask *sessionTask;

- (BOOL)isCancelled;
- (void)cancel;

@end
