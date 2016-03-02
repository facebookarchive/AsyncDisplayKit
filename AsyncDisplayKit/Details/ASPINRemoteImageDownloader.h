//
//  ASPINRemoteImageDownloader.h
//  Pods
//
//  Created by Garrett Moon on 2/5/16.
//
//

#import <Foundation/Foundation.h>
#import "ASImageProtocols.h"

@interface ASPINRemoteImageDownloader : NSObject <ASImageCacheProtocol, ASImageDownloaderProtocol>

+ (instancetype)sharedDownloader;

@end
