//
//  ASPINRemoteImageDownloader.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if PIN_REMOTE_IMAGE

#import <Foundation/Foundation.h>
#import "ASImageProtocols.h"
#import <PINRemoteImage/PINRemoteImageManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASPINRemoteImageDownloader : NSObject <ASImageCacheProtocol, ASImageDownloaderProtocol>

+ (ASPINRemoteImageDownloader *)sharedDownloader;

- (PINRemoteImageManager *)sharedPINRemoteImageManager;

@end

NS_ASSUME_NONNULL_END

#endif
