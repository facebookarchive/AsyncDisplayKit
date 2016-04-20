//
//  ASPINRemoteImageDownloader.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 2/5/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASImageProtocols.h"

@interface ASPINRemoteImageDownloader : NSObject <ASImageCacheProtocol, ASImageDownloaderProtocol>

+ (instancetype)sharedDownloader;

@end
