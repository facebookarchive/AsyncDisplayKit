//
//  ASAnimatedImage.m
//  Pods
//
//  Created by Garrett Moon on 3/18/16.
//
//

#import "ASAnimatedImage.h"

#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import "ASThread.h"

#if ASAnimatedImageDebug
#define ASAnimatedLog(...) NSLog(__VA_ARGS__)
#else
#define ASAnimatedLog(...)
#endif

static NSString *kASAnimatedImageErrorDomain = @"kASAnimatedImageErrorDomain";

const Float32 kASAnimatedImageDefaultDuration = 0.1;

static const size_t bitsPerComponent = 8;
static const size_t componentsPerPixel = 4;

static const NSUInteger maxFileSize = 50000000; //max file size in bytes
static const Float32 maxFileDuration = 1; //max duration of a file in seconds

const NSTimeInterval kASAnimatedImageDisplayRefreshRate = 60.0;
const Float32 kASAnimatedImageMinimumDuration = 1 / kASAnimatedImageDisplayRefreshRate;

//TODO separate out classes
@class ASSharedAnimatedImage;

typedef void(^ASAnimatedImageDecodedPath)(BOOL finished, NSString *path, NSError *error);
typedef void(^ASAnimatedImageInfoProcessed)(UIImage *coverImage, Float32 *durations, CFTimeInterval totalDuration, size_t loopCount, size_t frameCount, size_t width, size_t height, UInt32 bitmapInfo);
typedef void(^ASAnimatedImageSharedReady)(UIImage *coverImage, ASSharedAnimatedImage *shared);

BOOL ASStatusCoverImageCompleted(ASAnimatedImageStatus status);
BOOL ASStatusCoverImageCompleted(ASAnimatedImageStatus status) {
  return status == ASAnimatedImageStatusInfoProcessed || status == ASAnimatedImageStatusFirstFileProcessed || status == ASAnimatedImageStatusProcessed;
}

@interface ASSharedAnimatedImageFile : NSObject
{
  ASDN::Mutex _lock;
}

@property (nonatomic, strong, readonly) NSString *path;
@property (nonatomic, assign, readonly) UInt32 frameCount;
@property (nonatomic, weak, readonly) NSData *memoryMappedData;

- (instancetype)initWithPath:(NSString *)path NS_DESIGNATED_INITIALIZER;

@end

@interface ASSharedAnimatedImage : NSObject
{
  ASDN::Mutex _coverImageLock;
}

//This is intentionally atomic. ASAnimatedImageManager must be able to add entries
//and clients must be able to read them concurrently.
@property (atomic, strong, readwrite) NSArray <ASSharedAnimatedImageFile *> *maps;

@property (nonatomic, strong, readwrite) NSArray <ASAnimatedImageDecodedPath> *completions;
@property (nonatomic, strong, readwrite) NSArray <ASAnimatedImageSharedReady> *infoCompletions;
@property (nonatomic, weak, readwrite) UIImage *coverImage;
@property (nonatomic, strong, readwrite) NSError *error;
//TODO is status thread safe?
@property (nonatomic, assign, readwrite) ASAnimatedImageStatus status;

- (void)setInfoProcessedWithCoverImage:(UIImage *)coverImage durations:(Float32 *)durations totalDuration:(CFTimeInterval)totalDuration loopCount:(size_t)loopCount frameCount:(size_t)frameCount width:(size_t)width height:(size_t)height bitmapInfo:(CGBitmapInfo)bitmapInfo;

@property (nonatomic, readonly) Float32 *durations;
@property (nonatomic, readonly) CFTimeInterval totalDuration;
@property (nonatomic, readonly) size_t loopCount;
@property (nonatomic, readonly) size_t frameCount;
@property (nonatomic, readonly) size_t width;
@property (nonatomic, readonly) size_t height;
@property (nonatomic, readonly) CGBitmapInfo bitmapInfo;

@end

@interface ASAnimatedImageManager : NSObject
{
  ASDN::Mutex _lock;
}

+ (instancetype)sharedManager;

@property (nonatomic, strong, readonly) NSString *temporaryDirectory;
@property (nonatomic, strong, readonly) NSMutableDictionary <NSData *, ASSharedAnimatedImage *> *animatedImages;
@property (nonatomic, strong, readonly) dispatch_queue_t serialProcessingQueue;

@end

@interface ASAnimatedImage ()
{
  ASDN::Mutex _statusLock;
  ASDN::Mutex _completionLock;
  ASDN::Mutex _dataLock;
  
  NSData *_currentData;
  NSData *_nextData;
}

@property (nonatomic, strong, readonly) ASSharedAnimatedImage *sharedAnimatedImage;

+ (UIImage *)coverImageWithMemoryMap:(NSData *)memoryMap width:(UInt32)width height:(UInt32)height;

@end

@implementation ASAnimatedImageManager

+ (instancetype)sharedManager
{
  static dispatch_once_t onceToken;
  static ASAnimatedImageManager *sharedManager;
  dispatch_once(&onceToken, ^{
    sharedManager = [[ASAnimatedImageManager alloc] init];
  });
  return sharedManager;
}

- (instancetype)init
{
  if (self = [super init]) {
    //On iOS temp directories are not shared between apps. This may not be safe on OS X or other systems
    _temporaryDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ASAnimatedImageCache"];
    [self cleanupFiles];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:_temporaryDirectory] == NO) {
      [[NSFileManager defaultManager] createDirectoryAtPath:_temporaryDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    _animatedImages = [[NSMutableDictionary alloc] init];
    _serialProcessingQueue = dispatch_queue_create("Serial animated image processing queue.", DISPATCH_QUEUE_SERIAL);
    
    __weak ASAnimatedImageManager *weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
                                                    [weakSelf cleanupFiles];
                                                  }];
  }
  return self;
}

- (void)cleanupFiles
{
  [[NSFileManager defaultManager] removeItemAtPath:self.temporaryDirectory error:nil];
}

- (void)animatedPathForImageData:(NSData *)animatedImageData infoCompletion:(ASAnimatedImageSharedReady)infoCompletion completion:(ASAnimatedImageDecodedPath)completion
{
  BOOL startProcessing = NO;
  {
    ASDN::MutexLocker l(_lock);
    ASSharedAnimatedImage *shared = self.animatedImages[animatedImageData];
    if (shared == nil) {
      shared = [[ASSharedAnimatedImage alloc] init];
      self.animatedImages[animatedImageData] = shared;
      startProcessing = YES;
    }
    
    if (shared.status == ASAnimatedImageStatusProcessed) {
      if (completion) {
        completion(YES, nil, nil);
      }
    } else if (shared.error) {
      if (completion) {
        completion(NO, nil, shared.error);
      }
    } else {
      if (completion) {
        shared.completions = [shared.completions arrayByAddingObject:completion];
      }
    }
    
    if (ASStatusCoverImageCompleted(shared.status)) {
      if (infoCompletion) {
        infoCompletion(shared.coverImage, shared);
      }
    } else {
      if (infoCompletion) {
        shared.infoCompletions = [shared.infoCompletions arrayByAddingObject:infoCompletion];
      }
    }
  }
  
  if (startProcessing) {
    dispatch_async(self.serialProcessingQueue, ^{
      [[self class] processAnimatedImage:animatedImageData temporaryDirectory:self.temporaryDirectory infoCompletion:^(UIImage *coverImage, Float32 *durations, CFTimeInterval totalDuration, size_t loopCount, size_t frameCount, size_t width, size_t height, UInt32 bitmapInfo) {
        NSArray *infoCompletions = nil;
        ASSharedAnimatedImage *shared = nil;
        {
          ASDN::MutexLocker l(_lock);
          shared = self.animatedImages[animatedImageData];
          [shared setInfoProcessedWithCoverImage:coverImage durations:durations totalDuration:totalDuration loopCount:loopCount frameCount:frameCount width:width height:height bitmapInfo:bitmapInfo];
          infoCompletions = shared.infoCompletions;
          shared.infoCompletions = @[];
        }
        
        for (ASAnimatedImageSharedReady infoCompletion in infoCompletions) {
          infoCompletion(coverImage, shared);
        }
      } decodedPath:^(BOOL finished, NSString *path, NSError *error) {
        NSArray *completions = nil;
        NSData *memoryMappedData = nil;
        {
          ASDN::MutexLocker l(_lock);
          ASSharedAnimatedImage *shared = self.animatedImages[animatedImageData];
          
          if (path && error == nil) {
            shared.maps = [shared.maps arrayByAddingObject:[[ASSharedAnimatedImageFile alloc] initWithPath:path]];
          }
          shared.error = error;
          
          completions = shared.completions;
          if (finished || error) {
            shared.completions = @[];
          }
          
          if (finished) {
            shared.status = ASAnimatedImageStatusProcessed;
          } else {
            shared.status = ASAnimatedImageStatusFirstFileProcessed;
          }
        }
        
        for (ASAnimatedImageDecodedPath completion in completions) {
          completion(finished, path, error);
        }
      }];
    });
  }
}

+ (void)processAnimatedImage:(NSData *)animatedImageData
          temporaryDirectory:(NSString *)temporaryDirectory
              infoCompletion:(ASAnimatedImageInfoProcessed)infoCompletion
                 decodedPath:(ASAnimatedImageDecodedPath)completion
{
  NSUUID *UUID = [NSUUID UUID];
  NSError *error = nil;
  NSString *filePath = nil;
  //TODO Must handle file handle errors! Documentation says it throws exceptions on any errors :(
  NSFileHandle *fileHandle = [self fileHandle:&error filePath:&filePath temporaryDirectory:temporaryDirectory UUID:UUID count:0];
  UInt32 width;
  UInt32 height;
  UInt32 bitmapInfo;
  NSUInteger fileCount = 0;
  UInt32 frameCountForFile = 0;
  
#if ASAnimatedImageDebug
  CFTimeInterval start = CACurrentMediaTime();
#endif
  
  if (fileHandle && error == nil) {
    dispatch_queue_t diskWriteQueue = dispatch_queue_create("ASAnimatedImage disk write queue", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t diskGroup = dispatch_group_create();
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)animatedImageData,
                                                               (CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceTypeIdentifierHint : (__bridge NSString *)kUTTypeGIF,
                                                                                  (__bridge NSString *)kCGImageSourceShouldCache : (__bridge NSNumber *)kCFBooleanFalse});
    
    if (imageSource) {
      UInt32 frameCount = (UInt32)CGImageSourceGetCount(imageSource);
      NSDictionary *imageProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyProperties(imageSource, nil);
      UInt32 loopCount = (UInt32)[[[imageProperties objectForKey:(__bridge NSString *)kCGImagePropertyGIFDictionary]
                           objectForKey:(__bridge NSString *)kCGImagePropertyGIFLoopCount] unsignedLongValue];
      
      Float32 fileDuration = 0;
      NSUInteger fileSize = 0;
      Float32 durations[frameCount];
      CFTimeInterval totalDuration = 0;
      UIImage *coverImage = nil;
      
      //Gather header file info
      for (NSUInteger frameIdx = 0; frameIdx < frameCount; frameIdx++) {
        if (frameIdx == 0) {
          CGImageRef frameImage = CGImageSourceCreateImageAtIndex(imageSource, frameIdx, (CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache : (__bridge NSNumber *)kCFBooleanFalse});
          if (frameImage == nil) {
            error = [NSError errorWithDomain:kASAnimatedImageErrorDomain code:ASAnimatedImageErrorImageFrameError userInfo:nil];
            break;
          }
          
          bitmapInfo = CGImageGetBitmapInfo(frameImage);
          
          width = (UInt32)CGImageGetWidth(frameImage);
          height = (UInt32)CGImageGetHeight(frameImage);
          
          coverImage = [UIImage imageWithCGImage:frameImage];
          CGImageRelease(frameImage);
        }
        
        Float32 duration = [[self class] frameDurationAtIndex:frameIdx source:imageSource];
        durations[frameIdx] = duration;
        totalDuration += duration;
      }
      
      if (error == nil) {
        //Get size, write file header get coverImage
        
        //blockDurations will be freed below after calling infoCompletion
        Float32 *blockDurations = (Float32 *)malloc(sizeof(Float32) * frameCount);
        memcpy(blockDurations, durations, sizeof(Float32) * frameCount);
        
        dispatch_group_async(diskGroup, diskWriteQueue, ^{
          [self writeFileHeader:fileHandle width:width height:height loopCount:loopCount frameCount:frameCount bitmapInfo:bitmapInfo durations:blockDurations];
          [fileHandle closeFile];
        });
        fileCount = 1;
        fileHandle = [self fileHandle:&error filePath:&filePath temporaryDirectory:temporaryDirectory UUID:UUID count:fileCount];
        
        dispatch_group_async(diskGroup, diskWriteQueue, ^{
          ASAnimatedLog(@"notifying info");
          infoCompletion(coverImage, blockDurations, totalDuration, loopCount, frameCount, width, height, bitmapInfo);
          free(blockDurations);
          
          //write empty frame count
          [fileHandle writeData:[NSData dataWithBytes:&frameCountForFile length:sizeof(frameCountForFile)]];
        });
        
        //Process frames
        for (NSUInteger frameIdx = 0; frameIdx < frameCount; frameIdx++) {
          @autoreleasepool {
            if (fileDuration > maxFileDuration || fileSize > maxFileSize) {
              //create a new file
              dispatch_group_async(diskGroup, diskWriteQueue, ^{
                //prepend file with frameCount
                [fileHandle seekToFileOffset:0];
                [fileHandle writeData:[NSData dataWithBytes:&frameCountForFile length:sizeof(frameCountForFile)]];
                [fileHandle closeFile];
              });
              
              dispatch_group_async(diskGroup, diskWriteQueue, ^{
                ASAnimatedLog(@"notifying file: %@", filePath);
                completion(NO, filePath, error);
              });
              
              diskGroup = dispatch_group_create();
              fileCount++;
              fileHandle = [self fileHandle:&error filePath:&filePath temporaryDirectory:temporaryDirectory UUID:UUID count:fileCount];
              frameCountForFile = 0;
              fileDuration = 0;
              fileSize = 0;
              //write empty frame count
              dispatch_group_async(diskGroup, diskWriteQueue, ^{
                [fileHandle writeData:[NSData dataWithBytes:&frameCountForFile length:sizeof(frameCountForFile)]];
              });
            }
            
            CGImageRef frameImage = CGImageSourceCreateImageAtIndex(imageSource, frameIdx, (CFDictionaryRef)@{(__bridge NSString *)kCGImageSourceShouldCache : (__bridge NSNumber *)kCFBooleanFalse});
            if (frameImage == nil) {
              error = [NSError errorWithDomain:kASAnimatedImageErrorDomain code:ASAnimatedImageErrorImageFrameError userInfo:nil];
              break;
            }
            
            Float32 duration = durations[frameIdx];
            fileDuration += duration;
            NSData *frameData = (__bridge_transfer NSData *)CGDataProviderCopyData(CGImageGetDataProvider(frameImage));
            NSAssert(frameData.length == width * height * componentsPerPixel, @"data should be width * height * 4 bytes");
            dispatch_group_async(diskGroup, diskWriteQueue, ^{
              [self writeFrameToFile:fileHandle duration:duration frameData:frameData];
            });
            
            CGImageRelease(frameImage);
            frameCountForFile++;
          }
        }
      }
      
      CFRelease(imageSource);
    }
    
    dispatch_group_wait(diskGroup, DISPATCH_TIME_FOREVER);
    
    //close the file handle
    ASAnimatedLog(@"closing last file: %@", fileHandle);
    [fileHandle seekToFileOffset:0];
    [fileHandle writeData:[NSData dataWithBytes:&frameCountForFile length:sizeof(frameCountForFile)]];
    [fileHandle closeFile];
  }
  
#if ASAnimatedImageDebug
  CFTimeInterval interval = CACurrentMediaTime() - start;
  NSLog(@"Encoding and write time: %f", interval);
#endif
  
  completion(YES, filePath, error);
}

//http://stackoverflow.com/questions/16964366/delaytime-or-unclampeddelaytime-for-gifs
+ (Float32)frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source
{
  Float32 frameDuration = kASAnimatedImageDefaultDuration;
  NSDictionary *frameProperties = (__bridge_transfer NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, index, nil);
  // use unclamped delay time before delay time before default
  NSNumber *unclamedDelayTime = frameProperties[(__bridge NSString *)kCGImagePropertyGIFDictionary][(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime];
  if (unclamedDelayTime) {
    frameDuration = [unclamedDelayTime floatValue];
  } else {
    NSNumber *delayTime = frameProperties[(__bridge NSString *)kCGImagePropertyGIFDictionary][(__bridge NSString *)kCGImagePropertyGIFDelayTime];
    if (delayTime) {
      frameDuration = [delayTime floatValue];
    }
  }
  
  if (frameDuration < kASAnimatedImageMinimumDuration) {
    frameDuration = kASAnimatedImageDefaultDuration;
  }
  
  return frameDuration;
}

+ (NSString *)filePathWithTemporaryDirectory:(NSString *)temporaryDirectory UUID:(NSUUID *)UUID count:(NSUInteger)count
{
  NSString *filePath = [temporaryDirectory stringByAppendingPathComponent:[UUID UUIDString]];
  if (count > 0) {
    filePath = [filePath stringByAppendingString:[@(count) stringValue]];
  }
  return filePath;
}

+ (NSFileHandle *)fileHandle:(NSError **)error filePath:(NSString **)filePath temporaryDirectory:(NSString *)temporaryDirectory UUID:(NSUUID *)UUID count:(NSUInteger)count;
{
  NSString *dirPath = temporaryDirectory;
  NSString *outFilePath = [self filePathWithTemporaryDirectory:temporaryDirectory UUID:UUID count:count];
  NSError *outError = nil;
  NSFileHandle *fileHandle = nil;
  
  if (outError == nil) {
    BOOL success = [[NSFileManager defaultManager] createFileAtPath:outFilePath contents:nil attributes:nil];
    if (success == NO) {
      outError = [NSError errorWithDomain:kASAnimatedImageErrorDomain code:ASAnimatedImageErrorFileCreationError userInfo:nil];
    }
  }
  
  if (outError == nil) {
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:outFilePath];
    if (fileHandle == nil) {
      outError = [NSError errorWithDomain:kASAnimatedImageErrorDomain code:ASAnimatedImageErrorFileHandleError userInfo:nil];
    }
  }
  
  if (error) {
    *error = outError;
  }
  
  if (filePath) {
    *filePath = outFilePath;
  }
  
  return fileHandle;
}

/**
 ASAnimatedImage file header
 
 Header:
 [version] 2 bytes
 [width] 4 bytes
 [height] 4 bytes
 [loop count] 4 bytes
 [frame count] 4 bytes
 [bitmap info] 4 bytes
 [durations] 4 bytes * frame count
 
 */

+ (void)writeFileHeader:(NSFileHandle *)fileHandle width:(UInt32)width height:(UInt32)height loopCount:(UInt32)loopCount frameCount:(UInt32)frameCount bitmapInfo:(UInt32)bitmapInfo durations:(Float32*)durations
{
  UInt16 version = 1;
  [fileHandle writeData:[NSData dataWithBytes:&version length:sizeof(version)]];
  [fileHandle writeData:[NSData dataWithBytes:&width length:sizeof(width)]];
  [fileHandle writeData:[NSData dataWithBytes:&height length:sizeof(height)]];
  [fileHandle writeData:[NSData dataWithBytes:&loopCount length:sizeof(loopCount)]];
  [fileHandle writeData:[NSData dataWithBytes:&frameCount length:sizeof(frameCount)]];
  [fileHandle writeData:[NSData dataWithBytes:&bitmapInfo length:sizeof(bitmapInfo)]];
  [fileHandle writeData:[NSData dataWithBytes:durations length:sizeof(Float32) * frameCount]];
}

/**
 ASAnimatedImage frame file
 [frame count(in file)] 4 bytes
 [frame(s)]
 
 Each frame:
 [duration] 4 bytes
 [frame data] width * height * 4 bytes
 */

+ (void)writeFrameToFile:(NSFileHandle *)fileHandle duration:(Float32)duration frameData:(NSData *)frameData
{
  [fileHandle writeData:[NSData dataWithBytes:&duration length:sizeof(duration)]];
  [fileHandle writeData:frameData];
}

@end

@implementation ASAnimatedImage

- (instancetype)init
{
  return [self initWithAnimatedImageData:nil];
}

- (instancetype)initWithAnimatedImageData:(NSData *)animatedImageData
{
  if (self = [super init]) {
    ASDisplayNodeAssertNotNil(animatedImageData, @"animatedImageData must not be nil.");
    _status = ASAnimatedImageStatusUnprocessed;
    
    [[ASAnimatedImageManager sharedManager] animatedPathForImageData:animatedImageData infoCompletion:^(UIImage *coverImage, ASSharedAnimatedImage *shared) {
      {
        ASDN::MutexLocker l(_statusLock);
        _sharedAnimatedImage = shared;
        if (_status == ASAnimatedImageStatusUnprocessed) {
          _status = ASAnimatedImageStatusInfoProcessed;
        }
      }
      
      {
        ASDN::MutexLocker l(_completionLock);
        if (_infoCompletion) {
          _infoCompletion(coverImage);
        }
      }
    } completion:^(BOOL completed, NSString *path, NSError *error) {
      BOOL success = NO;
      {
        ASDN::MutexLocker l(_statusLock);
        
        if (_status == ASAnimatedImageStatusInfoProcessed) {
          _status = ASAnimatedImageStatusFirstFileProcessed;
        }
        
        if (completed && error == nil) {
          _status = ASAnimatedImageStatusProcessed;
          success = YES;
        } else if (error) {
          _status = ASAnimatedImageStatusError;
#if ASAnimatedImageDebug
          NSLog(@"animated image error: %@", error);
#endif
        }
      }
      
      {
        ASDN::MutexLocker l(_completionLock);
        if (_fileReady) {
          _fileReady();
        }
      }
      
      if (success) {
        ASDN::MutexLocker l(_completionLock);
        if (_animatedImageReady) {
          _animatedImageReady();
        }
      }
    }];
  }
  return self;
}

- (void)setInfoCompletion:(ASAnimatedImageInfoReady)infoCompletion
{
  ASDN::MutexLocker l(_completionLock);
  _infoCompletion = infoCompletion;
}

- (void)setAnimatedImageReady:(dispatch_block_t)animatedImageReady
{
  ASDN::MutexLocker l(_completionLock);
  _animatedImageReady = animatedImageReady;
}

- (void)setFileReady:(dispatch_block_t)fileReady
{
  ASDN::MutexLocker l(_completionLock);
  _fileReady = fileReady;
}

- (UIImage *)coverImageWithMemoryMap:(NSData *)memoryMap width:(UInt32)width height:(UInt32)height bitmapInfo:(CGBitmapInfo)bitmapInfo
{
  return [UIImage imageWithCGImage:[[self class] imageAtIndex:0 inMemoryMap:memoryMap width:width height:height bitmapInfo:bitmapInfo]];
}

void releaseData(void *data, const void *imageData, size_t size);

void releaseData(void *data, const void *imageData, size_t size)
{
  CFRelease(data);
}

- (CGImageRef)imageAtIndex:(NSUInteger)index inSharedImageFiles:(NSArray <ASSharedAnimatedImageFile *>*)imageFiles width:(UInt32)width height:(UInt32)height bitmapInfo:(CGBitmapInfo)bitmapInfo
{
  for (NSUInteger fileIdx = 0; fileIdx < imageFiles.count; fileIdx++) {
    ASSharedAnimatedImageFile *imageFile = imageFiles[fileIdx];
    if (index < imageFile.frameCount) {
      NSData *memoryMappedData = nil;
      {
        ASDN::MutexLocker l(_dataLock);
        memoryMappedData = imageFile.memoryMappedData;
        _currentData = memoryMappedData;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          ASDN::MutexLocker l(_dataLock);
          _nextData = (fileIdx + 1 < imageFiles.count) ? imageFiles[fileIdx + 1].memoryMappedData : imageFiles[0].memoryMappedData;
        });
      }
      return [[self class] imageAtIndex:index inMemoryMap:memoryMappedData width:width height:height bitmapInfo:bitmapInfo];
    } else {
      index -= imageFile.frameCount;
    }
  }
  //image file not done yet :(
  return nil;
}

+ (CGImageRef)imageAtIndex:(NSUInteger)index inMemoryMap:(NSData *)memoryMap width:(UInt32)width height:(UInt32)height bitmapInfo:(CGBitmapInfo)bitmapInfo
{
  Float32 outDuration;
  
  size_t imageLength = width * height * componentsPerPixel;
  
  //frame duration + previous images
  NSUInteger offset = sizeof(UInt32) + (index * (imageLength + sizeof(outDuration)));
  
  [memoryMap getBytes:&outDuration range:NSMakeRange(offset, sizeof(outDuration))];
  
  BytePtr imageData = (BytePtr)[memoryMap bytes];
  imageData += offset + sizeof(outDuration);
  
  ASDisplayNodeAssert(offset + sizeof(outDuration) + imageLength <= memoryMap.length, @"Requesting frame beyond data bounds");
  
  //retain the memory map, it will be released when releaseData is called
  CFRetain((CFDataRef)memoryMap);
  CGDataProviderRef dataProvider = CGDataProviderCreateWithData((void *)memoryMap, imageData, width * height * componentsPerPixel, releaseData);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGImageRef imageRef = CGImageCreate(width,
                                      height,
                                      bitsPerComponent,
                                      bitsPerComponent * componentsPerPixel,
                                      componentsPerPixel * width,
                                      colorSpace,
                                      bitmapInfo,
                                      dataProvider,
                                      NULL,
                                      NO,
                                      kCGRenderingIntentDefault);
  CFAutorelease(imageRef);
  
  CGColorSpaceRelease(colorSpace);
  CGDataProviderRelease(dataProvider);
  
  return imageRef;
}

+ (UInt32)widthFromMemoryMap:(NSData *)memoryMap
{
  UInt32 width;
  [memoryMap getBytes:&width range:NSMakeRange(2, sizeof(width))];
  return width;
}

+ (UInt32)heightFromMemoryMap:(NSData *)memoryMap
{
  UInt32 height;
  [memoryMap getBytes:&height range:NSMakeRange(6, sizeof(height))];
  return height;
}

+ (UInt32)loopCountFromMemoryMap:(NSData *)memoryMap
{
  UInt32 loopCount;
  [memoryMap getBytes:&loopCount range:NSMakeRange(10, sizeof(loopCount))];
  return loopCount;
}

+ (UInt32)frameCountFromMemoryMap:(NSData *)memoryMap
{
  UInt32 frameCount;
  [memoryMap getBytes:&frameCount range:NSMakeRange(14, sizeof(frameCount))];
  return frameCount;
}

+ (Float32 *)durationsFromMemoryMap:(NSData *)memoryMap frameCount:(UInt32)frameCount frameSize:(NSUInteger)frameSize totalDuration:(CFTimeInterval *)totalDuration
{
  *totalDuration = 0;
  Float32 durations[frameCount];
  [memoryMap getBytes:&durations range:NSMakeRange(18, sizeof(Float32) * frameCount)];

  for (NSUInteger idx = 0; idx < frameCount; idx++) {
    *totalDuration += durations[idx];
  }

  return durations;
}

- (Float32 *)durations
{
  return self.sharedAnimatedImage.durations;
}

- (CFTimeInterval)totalDuration
{
  return self.sharedAnimatedImage.totalDuration;
}

- (size_t)loopCount
{
  return self.sharedAnimatedImage.loopCount;
}

- (size_t)frameCount
{
  return self.sharedAnimatedImage.frameCount;
}

- (size_t)width
{
  return self.sharedAnimatedImage.width;
}

- (size_t)height
{
  return self.sharedAnimatedImage.height;
}

- (ASAnimatedImageStatus)status
{
  ASDN::MutexLocker l(_statusLock);
  return _status;
}

- (CGImageRef)imageAtIndex:(NSUInteger)index
{
  return [self imageAtIndex:index
         inSharedImageFiles:self.sharedAnimatedImage.maps
                      width:self.sharedAnimatedImage.width
                     height:self.sharedAnimatedImage.height
                 bitmapInfo:self.sharedAnimatedImage.bitmapInfo];
}

- (UIImage *)coverImage
{
  return self.sharedAnimatedImage.coverImage;
}

- (void)clearMemoryCache
{
  ASDN::MutexLocker l(_dataLock);
  _currentData = nil;
  _nextData = nil;
}

@end

@implementation ASSharedAnimatedImage

- (instancetype)init
{
  if (self = [super init]) {
    _completions = @[];
    _infoCompletions = @[];
    _maps = @[];
  }
  return self;
}

- (void)setInfoProcessedWithCoverImage:(UIImage *)coverImage durations:(Float32 *)durations totalDuration:(CFTimeInterval)totalDuration loopCount:(size_t)loopCount frameCount:(size_t)frameCount width:(size_t)width height:(size_t)height bitmapInfo:(CGBitmapInfo)bitmapInfo
{
  ASDisplayNodeAssert(_status == ASAnimatedImageStatusUnprocessed, @"Status should be unprocessed.");
  {
    ASDN::MutexLocker l(_coverImageLock);
    _coverImage = coverImage;
  }
  _durations = (Float32 *)malloc(sizeof(Float32) * frameCount);
  memcpy(_durations, durations, sizeof(Float32) * frameCount);
  _totalDuration = totalDuration;
  _loopCount = loopCount;
  _frameCount = frameCount;
  _width = width;
  _height = height;
  _bitmapInfo = bitmapInfo;
  _status = ASAnimatedImageStatusInfoProcessed;
}

- (void)dealloc
{
  free(_durations);
}

- (UIImage *)coverImage
{
  ASDN::MutexLocker l(_coverImageLock);
  UIImage *coverImage = nil;
  if (_coverImage == nil) {
    coverImage = [UIImage imageWithCGImage:[ASAnimatedImage imageAtIndex:0 inMemoryMap:self.maps[0].memoryMappedData width:self.width height:self.height bitmapInfo:self.bitmapInfo]];
    _coverImage = coverImage;
  } else {
    coverImage = _coverImage;
  }
  return coverImage;
}

@end

@implementation ASSharedAnimatedImageFile

@synthesize memoryMappedData = _memoryMappedData;
@synthesize frameCount = _frameCount;

- (instancetype)initWithPath:(NSString *)path
{
  if (self = [super init]) {
    _path = path;
  }
  return self;
}

- (UInt32)frameCount
{
  ASDN::MutexLocker l(_lock);
  if (_frameCount == 0) {
    NSData *memoryMappedData = _memoryMappedData;
    if (memoryMappedData == nil) {
      memoryMappedData = [self loadMemoryMappedData];
    }
    [memoryMappedData getBytes:&_frameCount range:NSMakeRange(0, sizeof(_frameCount))];
  }
  return _frameCount;
}

- (NSData *)memoryMappedData
{
  ASDN::MutexLocker l(_lock);
  if (_memoryMappedData == nil) {
    return [self loadMemoryMappedData];
  }
  return _memoryMappedData;
}

//must be called within lock
- (NSData *)loadMemoryMappedData
{
  NSError *error = nil;
  _memoryMappedData = [NSData dataWithContentsOfFile:self.path options:NSDataReadingMappedAlways error:&error];
  if (error) {
#if ASAnimatedImageDebug
    NSLog(@"Could not memory map data: %@", error);
#endif
  }
  return _memoryMappedData;
}

@end
