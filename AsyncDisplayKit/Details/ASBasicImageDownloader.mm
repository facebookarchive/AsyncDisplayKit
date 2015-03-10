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

#import "ASBasicImageDownloaderInternal.h"
#import "ASThread.h"


#pragma mark -
/**
 * Collection of properties associated with a download request.
 */
@interface ASBasicImageDownloaderContext ()
{
  BOOL _invalid;
  ASDN::RecursiveMutex _propertyLock;
}

@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, copy) void (^downloadProgressBlock)(CGFloat);
@property (nonatomic, copy) void (^completionBlock)(CGImageRef, NSError *);

@end

@implementation ASBasicImageDownloaderContext

static NSMutableDictionary *currentRequests = nil;
static ASDN::RecursiveMutex currentRequestsLock;

+ (ASBasicImageDownloaderContext *)contextForURL:(NSURL *)URL
{
  ASDN::MutexLocker l(currentRequestsLock);
  if (!currentRequests) {
    currentRequests = [[NSMutableDictionary alloc] init];
  }
  ASBasicImageDownloaderContext *context = currentRequests[URL];
  if (!context) {
    context = [[ASBasicImageDownloaderContext alloc] initWithURL:URL];
    currentRequests[URL] = context;
  }
  return context;
}

+ (void)cancelContextWithURL:(NSURL *)URL
{
  ASDN::MutexLocker l(currentRequestsLock);
  if (currentRequests) {
    [currentRequests removeObjectForKey:URL];
  }
}

- (instancetype)initWithURL:(NSURL *)URL
{
  if (self = [super init]) {
    _URL = URL;
  }
  return self;
}

- (void)cancel
{
  ASDN::MutexLocker l(_propertyLock);

  NSURLSessionTask *sessionTask = self.sessionTask;
  if (sessionTask) {
    [sessionTask cancel];
    self.sessionTask = nil;
  }

  _invalid = YES;
  [self.class cancelContextWithURL:self.URL];
}

- (BOOL)isCancelled
{
  ASDN::MutexLocker l(_propertyLock);
  return _invalid;
}

@end


#pragma mark -
/**
 * NSURLSessionDownloadTask lacks a `userInfo` property, so add this association ourselves.
 */
@interface NSURLRequest (ASBasicImageDownloader)
@property (nonatomic, strong) ASBasicImageDownloaderContext *asyncdisplaykit_context;
@end

@implementation NSURLRequest (ASBasicImageDownloader)
static const char *kContextKey = NSStringFromClass(ASBasicImageDownloaderContext.class).UTF8String;
- (void)setAsyncdisplaykit_context:(ASBasicImageDownloaderContext *)asyncdisplaykit_context
{
  objc_setAssociatedObject(self, kContextKey, asyncdisplaykit_context, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (ASBasicImageDownloader *)asyncdisplaykit_context
{
  return objc_getAssociatedObject(self, kContextKey);
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
  ASBasicImageDownloaderContext *context = [ASBasicImageDownloaderContext contextForURL:URL];

  // NSURLSessionDownloadTask will do file I/O to create a temp directory. If called on the main thread this will
  // cause significant performance issues.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    // the downloader may have been invalidated in the time it takes to async dispatch this block
    if ([context isCancelled]) {
      return;
    }
    
    // create download task
    NSURLSessionDownloadTask *task = [_session downloadTaskWithURL:URL];

    // since creating the task does disk I/O, we should check if it has been invalidated
    if ([context isCancelled]) {
      return;
    }

    // associate metadata with it
    context.callbackQueue = callbackQueue ?: dispatch_get_main_queue();
    context.downloadProgressBlock = downloadProgressBlock;
    context.completionBlock = completion;
    context.sessionTask = task;
    task.originalRequest.asyncdisplaykit_context = context;

    // start downloading
    [task resume];

    context.sessionTask = task;
  });

  return context;
}

- (void)cancelImageDownloadForIdentifier:(id)downloadIdentifier
{
  if (!downloadIdentifier) {
    return;
  }

  ASDisplayNodeAssert([downloadIdentifier isKindOfClass:ASBasicImageDownloaderContext.class], @"unexpected downloadIdentifier");
  ASBasicImageDownloaderContext *context = (ASBasicImageDownloaderContext *)downloadIdentifier;

  [context cancel];
}


#pragma mark NSURLSessionDownloadDelegate.

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASBasicImageDownloaderContext *context = downloadTask.originalRequest.asyncdisplaykit_context;
  if (context.downloadProgressBlock) {
    context.downloadProgressBlock((CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite);
  }
}

// invoked if the download succeeded with no error
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location
{
  ASBasicImageDownloaderContext *context = downloadTask.originalRequest.asyncdisplaykit_context;
  if ([context isCancelled]) {
    return;
  }

  UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:location]];

  if (context.completionBlock) {
    dispatch_async(context.callbackQueue, ^{
      context.completionBlock(image.CGImage, nil);
    });
  }
}

// invoked unconditionally
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionDownloadTask *)task
                           didCompleteWithError:(NSError *)error
{
  ASBasicImageDownloaderContext *context = task.originalRequest.asyncdisplaykit_context;
  if (context && error) {
    dispatch_async(context.callbackQueue, ^{
      context.completionBlock(NULL, error);
    });
  }
}

@end
