/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASImageNode.h"

#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>
#import <AsyncDisplayKit/ASDisplayNodeInternal.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>

#import "ASImageNode+CGExtras.h"

#import "ASInternalHelpers.h"
#import "ASEqualityHelpers.h"

@interface _ASImageNodeDrawParameters : NSObject

@property (nonatomic, assign) BOOL opaque;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) CGFloat contentsScale;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, assign) UIViewContentMode contentMode;

@end

// TODO: eliminate explicit parameters with a set of keys copied from the node
@implementation _ASImageNodeDrawParameters

- (id)initWithBounds:(CGRect)bounds opaque:(BOOL)opaque contentsScale:(CGFloat)contentsScale backgroundColor:(UIColor *)backgroundColor contentMode:(UIViewContentMode)contentMode
{
  self = [self init];
  if (!self) return nil;

  _opaque = opaque;
  _bounds = bounds;
  _contentsScale = contentsScale;
  _backgroundColor = backgroundColor;
  _contentMode = contentMode;

  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@ : %p opaque:%@ bounds:%@ contentsScale:%.2f backgroundColor:%@ contentMode:%@>", [self class], self, @(self.opaque), NSStringFromCGRect(self.bounds), self.contentsScale, self.backgroundColor, ASDisplayNodeNSStringFromUIContentMode(self.contentMode)];
}

@end


@implementation ASImageNode
{
@private
  UIImage *_image;

  void (^_displayCompletionBlock)(BOOL canceled);
  ASDN::RecursiveMutex _imageLock;

  // Cropping.
  BOOL _cropEnabled; // Defaults to YES.
  BOOL _forceUpscaling; //Defaults to NO.
  CGRect _cropRect; // Defaults to CGRectMake(0.5, 0.5, 0, 0)
  CGRect _cropDisplayBounds;
}

@synthesize image = _image;
@synthesize imageModificationBlock = _imageModificationBlock;

- (id)init
{
  if (!(self = [super init]))
    return nil;

  // TODO can this be removed?
  self.contentsScale = ASScreenScale();
  self.contentMode = UIViewContentModeScaleAspectFill;
  self.opaque = NO;

  _cropEnabled = YES;
  _forceUpscaling = NO;
  _cropRect = CGRectMake(0.5, 0.5, 0, 0);
  _cropDisplayBounds = CGRectNull;
  _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();

  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDN::MutexLocker l(_imageLock);
  // if a preferredFrameSize is set, call the superclass to return that instead of using the image size.
  if (CGSizeEqualToSize(self.preferredFrameSize, CGSizeZero) == NO)
    return [super calculateSizeThatFits:constrainedSize];
  else if (_image)
    return _image.size;
  else
    return CGSizeZero;
}

- (void)setImage:(UIImage *)image
{
  ASDN::MutexLocker l(_imageLock);
  if (!ASObjectIsEqual(_image, image)) {
    _image = image;

    [self invalidateCalculatedLayout];
    [self setNeedsDisplay];
  }
}

- (UIImage *)image
{
  ASDN::MutexLocker l(_imageLock);
  return _image;
}

- (void)setPlaceholderColor:(UIColor *)placeholderColor
{
  _placeholderColor = placeholderColor;

  // prevent placeholders if we don't have a color
  self.placeholderEnabled = placeholderColor != nil;
}

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer
{
  return [[_ASImageNodeDrawParameters alloc] initWithBounds:self.bounds
                                                     opaque:self.opaque
                                              contentsScale:self.contentsScaleForDisplay
                                            backgroundColor:self.backgroundColor
                                                contentMode:self.contentMode];
}

- (UIImage *)displayWithParameters:(_ASImageNodeDrawParameters *)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  UIImage *image;
  BOOL cropEnabled;
  BOOL forceUpscaling;
  CGFloat contentsScale;
  CGRect cropDisplayBounds;
  CGRect cropRect;
  asimagenode_modification_block_t imageModificationBlock;
  
  {
    ASDN::MutexLocker l(_imageLock);
    image = _image;
    if (!image) {
      return nil;
    }
    
    cropEnabled = _cropEnabled;
    forceUpscaling = _forceUpscaling;
    contentsScale = _contentsScaleForDisplay;
    cropDisplayBounds = _cropDisplayBounds;
    cropRect = _cropRect;
    imageModificationBlock = _imageModificationBlock;
  }
  
  ASDisplayNodeContextModifier preContextBlock = self.willDisplayNodeContentWithRenderingContext;
  ASDisplayNodeContextModifier postContextBlock = self.didDisplayNodeContentWithRenderingContext;
  
  BOOL hasValidCropBounds = cropEnabled && !CGRectIsNull(cropDisplayBounds) && !CGRectIsEmpty(cropDisplayBounds);
  
  CGRect bounds = (hasValidCropBounds ? cropDisplayBounds : parameters.bounds);
  BOOL isOpaque = parameters.opaque;
  UIColor *backgroundColor = parameters.backgroundColor;
  UIViewContentMode contentMode = parameters.contentMode;
  
  ASDisplayNodeAssert(contentsScale > 0, @"invalid contentsScale at display time");
  
  // if the image is resizable, bail early since the image has likely already been configured
  BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
  if (stretchable) {
    if (imageModificationBlock != NULL) {
      image = imageModificationBlock(image);
    }
    return image;
  }
  
  CGSize imageSize = image.size;
  CGSize imageSizeInPixels = CGSizeMake(imageSize.width * image.scale, imageSize.height * image.scale);
  CGSize boundsSizeInPixels = CGSizeMake(floorf(bounds.size.width * contentsScale), floorf(bounds.size.height * contentsScale));
  
  BOOL contentModeSupported =    contentMode == UIViewContentModeScaleAspectFill
  || contentMode == UIViewContentModeScaleAspectFit
  || contentMode == UIViewContentModeCenter;
  
  CGSize backingSize;
  CGRect imageDrawRect;
  
  if (boundsSizeInPixels.width * contentsScale < 1.0f ||
      boundsSizeInPixels.height * contentsScale < 1.0f ||
      imageSizeInPixels.width < 1.0f ||
      imageSizeInPixels.height < 1.0f) {
    return nil;
  }
  
  // If we're not supposed to do any cropping, just decode image at original size
  if (!cropEnabled || !contentModeSupported || stretchable) {
    backingSize = imageSizeInPixels;
    imageDrawRect = (CGRect){.size = backingSize};
  } else {
    ASCroppedImageBackingSizeAndDrawRectInBounds(imageSizeInPixels,
                                                 boundsSizeInPixels,
                                                 contentMode,
                                                 cropRect,
                                                 forceUpscaling,
                                                 &backingSize,
                                                 &imageDrawRect);
  }
  
  if (backingSize.width <= 0.0f ||
      backingSize.height <= 0.0f ||
      imageDrawRect.size.width <= 0.0f ||
      imageDrawRect.size.height <= 0.0f) {
    return nil;
  }
  
  // Use contentsScale of 1.0 and do the contentsScale handling in boundsSizeInPixels so ASCroppedImageBackingSizeAndDrawRectInBounds
  // will do its rounding on pixel instead of point boundaries
  UIGraphicsBeginImageContextWithOptions(backingSize, isOpaque, 1.0);
  
  CGContextRef context = UIGraphicsGetCurrentContext();
  if (context && preContextBlock) {
    preContextBlock(context);
  }
  
  // if view is opaque, fill the context with background color
  if (isOpaque && backgroundColor) {
    [backgroundColor setFill];
    UIRectFill({ .size = backingSize });
  }
  
  // iOS 9 appears to contain a thread safety regression when drawing the same CGImageRef on
  // multiple threads concurrently.  In fact, instead of crashing, it appears to deadlock.
  // The issue is present in Mac OS X El Capitan and has been seen hanging Pro apps like Adobe Premier,
  // as well as iOS games, and a small number of ASDK apps that provide the same image reference
  // to many separate ASImageNodes.  A workaround is to set .displaysAsynchronously = NO for the nodes
  // that may get the same pointer for a given UI asset image, etc.
  // FIXME: We should replace @synchronized here, probably using a global, locked NSMutableSet, and
  // only if the object already exists in the set we should create a semaphore to signal waiting threads
  // upon removal of the object from the set when the operation completes.
  // Another option is to have ASDisplayNode+AsyncDisplay coordinate these cases, and share the decoded buffer.
  // Details tracked in https://github.com/facebook/AsyncDisplayKit/issues/1068
  
  @synchronized(image) {
    [image drawInRect:imageDrawRect];
  }
  
  if (context && postContextBlock) {
    postContextBlock(context);
  }
  
  if (isCancelled()) {
    UIGraphicsEndImageContext();
    return nil;
  }
  
  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
  
  UIGraphicsEndImageContext();
  
  if (imageModificationBlock != NULL) {
    result = imageModificationBlock(result);
  }
  
  return result;
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  ASDN::MutexLocker l(_imageLock);

  void (^displayCompletionBlock)(BOOL canceled) = _displayCompletionBlock;
  UIImage *image = _image;
  
  ASDN::MutexLocker u(_imageLock);
  
  // If we've got a block to perform after displaying, do it.
  if (image && displayCompletionBlock) {

    displayCompletionBlock(NO);
    
    ASDN::MutexLocker l(_imageLock);
    _displayCompletionBlock = nil;
    ASDN::MutexLocker u(_imageLock);
  }
}

#pragma mark -
- (void)setNeedsDisplayWithCompletion:(void (^ _Nullable)(BOOL canceled))displayCompletionBlock
{
  if (self.displaySuspended) {
    if (displayCompletionBlock)
      displayCompletionBlock(YES);
    return;
  }

  // Stash the block and call-site queue. We'll invoke it in -displayDidFinish.
  ASDN::MutexLocker l(_imageLock);
  if (_displayCompletionBlock != displayCompletionBlock) {
    _displayCompletionBlock = [displayCompletionBlock copy];
  }

  [self setNeedsDisplay];
}

#pragma mark - Cropping
- (BOOL)isCropEnabled
{
  ASDN::MutexLocker l(_imageLock);
  return _cropEnabled;
}

- (void)setCropEnabled:(BOOL)cropEnabled
{
  [self setCropEnabled:cropEnabled recropImmediately:NO inBounds:self.bounds];
}

- (void)setCropEnabled:(BOOL)cropEnabled recropImmediately:(BOOL)recropImmediately inBounds:(CGRect)cropBounds
{
  ASDN::MutexLocker l(_imageLock);
  if (_cropEnabled == cropEnabled)
    return;

  _cropEnabled = cropEnabled;
  _cropDisplayBounds = cropBounds;

  // If we have an image to display, display it, respecting our recrop flag.
  if (self.image)
  {
    ASPerformBlockOnMainThread(^{
      if (recropImmediately)
        [self displayImmediately];
      else
        [self setNeedsDisplay];
    });
  }
}

- (CGRect)cropRect
{
  ASDN::MutexLocker l(_imageLock);
  return _cropRect;
}

- (void)setCropRect:(CGRect)cropRect
{
  ASDN::MutexLocker l(_imageLock);
  if (CGRectEqualToRect(_cropRect, cropRect))
    return;

  _cropRect = cropRect;

  // TODO: this logic needs to be updated to respect cropRect.
  CGSize boundsSize = self.bounds.size;
  CGSize imageSize = self.image.size;

  BOOL isCroppingImage = ((boundsSize.width < imageSize.width) || (boundsSize.height < imageSize.height));

  // Re-display if we need to.
  ASPerformBlockOnMainThread(^{
    if (self.nodeLoaded && self.contentMode == UIViewContentModeScaleAspectFill && isCroppingImage)
      [self setNeedsDisplay];
  });
}

- (BOOL)forceUpscaling
{
  ASDN::MutexLocker l(_imageLock);
  return _forceUpscaling;
}

- (void)setForceUpscaling:(BOOL)forceUpscaling
{
  ASDN::MutexLocker l(_imageLock);
  _forceUpscaling = forceUpscaling;
}

- (asimagenode_modification_block_t)imageModificationBlock
{
  ASDN::MutexLocker l(_imageLock);
  return _imageModificationBlock;
}

- (void)setImageModificationBlock:(asimagenode_modification_block_t)imageModificationBlock
{
  ASDN::MutexLocker l(_imageLock);
  _imageModificationBlock = imageModificationBlock;
}

@end


#pragma mark - Extras
extern asimagenode_modification_block_t ASImageNodeRoundBorderModificationBlock(CGFloat borderWidth, UIColor *borderColor)
{
  return ^(UIImage *originalImage) {
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    UIBezierPath *roundOutline = [UIBezierPath bezierPathWithOvalInRect:(CGRect){CGPointZero, originalImage.size}];

    // Make the image round
    [roundOutline addClip];

    // Draw the original image
    [originalImage drawAtPoint:CGPointZero];

    // Draw a border on top.
    if (borderWidth > 0.0) {
      [borderColor setStroke];
      [roundOutline setLineWidth:borderWidth];
      [roundOutline stroke];
    }

    UIImage *modifiedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return modifiedImage;
  };
}

extern asimagenode_modification_block_t ASImageNodeTintColorModificationBlock(UIColor *color)
{
  return ^(UIImage *originalImage) {
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    
    // Set color and render template
    [color setFill];
    UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [templateImage drawAtPoint:CGPointZero];
    
    UIImage *modifiedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // if the original image was stretchy, keep it stretchy
    if (!UIEdgeInsetsEqualToEdgeInsets(originalImage.capInsets, UIEdgeInsetsZero)) {
      modifiedImage = [modifiedImage resizableImageWithCapInsets:originalImage.capInsets resizingMode:originalImage.resizingMode];
    }

    return modifiedImage;
  };
}

