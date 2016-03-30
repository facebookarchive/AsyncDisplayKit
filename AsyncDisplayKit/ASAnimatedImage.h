//
//  ASAnimatedImage.h
//  Pods
//
//  Created by Garrett Moon on 3/18/16.
//
//

#import <Foundation/Foundation.h>

#define ASAnimatedImageDebug  0

typedef NS_ENUM(NSUInteger, ASAnimatedImageError) {
  ASAnimatedImageErrorNoError = 0,
  ASAnimatedImageErrorFileCreationError,
  ASAnimatedImageErrorFileHandleError,
  ASAnimatedImageErrorImageFrameError,
  ASAnimatedImageErrorMappingError,
};

typedef NS_ENUM(NSUInteger, ASAnimatedImageStatus) {
  ASAnimatedImageStatusUnprocessed = 0,
  ASAnimatedImageStatusInfoProcessed,
  ASAnimatedImageStatusFirstFileProcessed,
  ASAnimatedImageStatusProcessed,
  ASAnimatedImageStatusCanceled,
  ASAnimatedImageStatusError,
};

extern const Float32 kASAnimatedImageDefaultDuration;
//http://nullsleep.tumblr.com/post/16524517190/animated-gif-minimum-frame-delay-browser
extern const Float32 kASAnimatedImageMinimumDuration;
extern const NSTimeInterval kASAnimatedImageDisplayRefreshRate;

typedef void(^ASAnimatedImageInfoReady)(UIImage *coverImage);

@interface ASAnimatedImage : NSObject

- (instancetype)initWithAnimatedImageData:(NSData *)animatedImageData NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readwrite) ASAnimatedImageInfoReady infoCompletion;
@property (nonatomic, strong, readwrite) dispatch_block_t fileReady;
@property (nonatomic, strong, readwrite) dispatch_block_t animatedImageReady;

@property (nonatomic, assign, readwrite) ASAnimatedImageStatus status;

//Access to any properties or methods below this line before status == ASAnimatedImageStatusInfoProcessed is undefined.
@property (nonatomic, readonly) UIImage *coverImage;
@property (nonatomic, readonly) Float32 *durations;
@property (nonatomic, readonly) CFTimeInterval totalDuration;
@property (nonatomic, readonly) size_t loopCount;
@property (nonatomic, readonly) size_t frameCount;
@property (nonatomic, readonly) size_t width;
@property (nonatomic, readonly) size_t height;

- (CGImageRef)imageAtIndex:(NSUInteger)index;
- (void)clearMemoryCache;

@end
