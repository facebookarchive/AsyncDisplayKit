/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASBasicImageDownloader.h"

#import <objc/runtime.h>

#import <UIKit/UIKit.h>

#import "ASThread.h"


#pragma mark -
/**
 * Collection of properties associated with a download request.
 */
@interface ASBasicImageDownloaderMetadata : NSObject
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) void (^downloadProgressBlock)(CGFloat);
@property (nonatomic, strong) void (^completionBlock)(CGImageRef, NSError *);
@end

@implementation ASBasicImageDownloaderMetadata
@end


#pragma mark -
/**
 * NSURLSessionDownloadTask lacks a `userInfo` property, so add this association ourselves.
 */
@interface NSURLRequest (ASBasicImageDownloader)
@property (nonatomic, strong) ASBasicImageDownloaderMetadata *asyncdisplaykit_metadata;
@end

@implementation NSURLRequest (ASBasicImageDownloader)
static const char *kMetadataKey = NSStringFromClass(ASBasicImageDownloaderMetadata.class).UTF8String;
- (void)setAsyncdisplaykit_metadata:(ASBasicImageDownloaderMetadata *)asyncdisplaykit_metadata
{
  objc_setAssociatedObject(self, kMetadataKey, asyncdisplaykit_metadata, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (ASBasicImageDownloader *)asyncdisplaykit_metadata
{
  return objc_getAssociatedObject(self, kMetadataKey);
}
@end


#pragma mark -
@interface ASBasicImageDownloader () <NSURLSessionDownloadDelegate>
{
  NSOperationQueue *_sessionDelegateQueue;
  NSURLSession *_session;
}

@end

@implementation ASBasicImageDownloader

#pragma mark Lifecycle.

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _sessionDelegateQueue = [[NSOperationQueue alloc] init];
  _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                           delegate:self
                                      delegateQueue:_sessionDelegateQueue];

  return self;
}


#pragma mark ASImageDownloaderProtocol.

- (id)downloadImageWithURL:(NSURL *)URL
             callbackQueue:(dispatch_queue_t)callbackQueue
     downloadProgressBlock:(void (^)(CGFloat))downloadProgressBlock
                completion:(void (^)(CGImageRef, NSError *))completion
{
  // create download task
  NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:URL];

  // associate metadata with it
  ASBasicImageDownloaderMetadata *metadata = [[ASBasicImageDownloaderMetadata alloc] init];
  metadata.callbackQueue = callbackQueue ?: dispatch_get_main_queue();
  metadata.downloadProgressBlock = downloadProgressBlock;
  metadata.completionBlock = completion;
  task.originalRequest.asyncdisplaykit_metadata = metadata;

  // start downloading
  [task resume];

  // return the task as an opaque cancellation token
  return task;
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  if (!downloadIdentifier) {
    return;
  }

  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:NSURLSessionDownloadTask.class], @"unexpected downloadIdentifier");
  NSURLSessionDownloadTask *task = (NSURLSessionDownloadTask *)downloadIdentifier;

  [task cancel];
}


#pragma mark NSURLSessionDownloadDelegate.

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASBasicImageDownloaderMetadata *metadata = downloadTask.originalRequest.asyncdisplaykit_metadata;
  if (metadata.downloadProgressBlock) {
    metadata.downloadProgressBlock((CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite);
  }
}

// invoked if the download succeeded with no error
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location
{
  UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];

  ASBasicImageDownloaderMetadata *metadata = downloadTask.originalRequest.asyncdisplaykit_metadata;
  if (metadata.completionBlock) {
    dispatch_async(metadata.callbackQueue, ^{
      metadata.completionBlock(image.CGImage, nil);
    });
  }
}

// invoked unconditionally
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)task
                           didCompleteWithError:(NSError *)error
{
  ASBasicImageDownloaderMetadata *metadata = task.originalRequest.asyncdisplaykit_metadata;
  if (metadata && error) {
    dispatch_async(metadata.callbackQueue, ^{
      metadata.completionBlock(NULL, error);
    });
  }
}

@end
