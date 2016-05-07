//
//  ASPINRemoteImageDownloader.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASImageProtocols.h"

NS_ASSUME_NONNULL_BEGIN

@interface ASPINRemoteImageDownloader : NSObject <ASImageCacheProtocol, ASImageDownloaderProtocol>

+ (ASPINRemoteImageDownloader *)sharedDownloader;

@end

NS_ASSUME_NONNULL_END
