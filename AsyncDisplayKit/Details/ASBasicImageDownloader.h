//
//  ASBasicImageDownloader.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASImageProtocols.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * @abstract Simple NSURLSession-based image downloader.
 */
@interface ASBasicImageDownloader : NSObject <ASImageDownloaderProtocolDeprecated, ASImageDownloaderProtocol>

+ (instancetype)sharedImageDownloader;

+ (instancetype)new __attribute__((unavailable("+[ASBasicImageDownloader sharedImageDownloader] must be used.")));
- (instancetype)init __attribute__((unavailable("+[ASBasicImageDownloader sharedImageDownloader] must be used.")));

@end

NS_ASSUME_NONNULL_END
