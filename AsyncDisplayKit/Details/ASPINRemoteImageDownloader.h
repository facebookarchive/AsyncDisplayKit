//
//  ASPINRemoteImageDownloader.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
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
