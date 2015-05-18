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

#import "ASImageNode+CGExtras.h"

@interface _ASImageNodeDrawParameters : NSObject

@property (nonatomic, assign, readonly) BOOL cropEnabled;
@property (nonatomic, assign) BOOL opaque;
@property (nonatomic, retain) UIImage *image;
@property (nonatomic, assign) CGRect bounds;
@property (nonatomic, assign) CGFloat contentsScale;
@property (nonatomic, retain) UIColor *backgroundColor;
@property (nonatomic, assign) UIViewContentMode contentMode;
@property (nonatomic, assign) CGRect cropRect;
@property (nonatomic, copy) asimagenode_modification_block_t imageModificationBlock;

@end

// TODO: eliminate explicit parameters with a set of keys copied from the node
@implementation _ASImageNodeDrawParameters

- (id)initWithCrop:(BOOL)cropEnabled opaque:(BOOL)opaque image:(UIImage *)image bounds:(CGRect)bounds contentsScale:(CGFloat)contentsScale backgroundColor:(UIColor *)backgroundColor contentMode:(UIViewContentMode)contentMode cropRect:(CGRect)cropRect imageModificationBlock:(asimagenode_modification_block_t)imageModificationBlock
{
  self = [self init];
  if (!self) return nil;

  _cropEnabled = cropEnabled;
  _opaque = opaque;
  _image = image;
  _bounds = bounds;
  _contentsScale = contentsScale;
  _backgroundColor = backgroundColor;
  _contentMode = contentMode;
  _cropRect = cropRect;
  _imageModificationBlock = [imageModificationBlock copy];

  return self;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"<%@ : %p image:%@ cropEnabled:%@ opaque:%@ bounds:%@ contentsScale:%.2f backgroundColor:%@ contentMode:%@ cropRect:%@>", [self class], self, self.image, @(self.cropEnabled), @(self.opaque), NSStringFromCGRect(self.bounds), self.contentsScale, self.backgroundColor, ASDisplayNodeNSStringFromUIContentMode(self.contentMode), NSStringFromCGRect(self.cropRect)];
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
  CGRect _cropRect; // Defaults to CGRectMake(0.5, 0.5, 0, 0)
  CGRect _cropDisplayBounds;
}

@synthesize image = _image;

- (id)init
{
  if (!(self = [super init]))
    return nil;

  // TODO can this be removed?
  self.contentsScale = ASDisplayNodeScreenScale();
  self.contentMode = UIViewContentModeScaleAspectFill;
  self.opaque = NO;

  _cropEnabled = YES;
  _cropRect = CGRectMake(0.5, 0.5, 0, 0);
  _cropDisplayBounds = CGRectNull;
  _placeholderColor = ASDisplayNodeDefaultPlaceholderColor();

  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  ASDisplayNodeAssertNotSupported();
  return nil;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDN::MutexLocker l(_imageLock);
  if (_image)
    return _image.size;
  else
    return CGSizeZero;
}

- (void)setImage:(UIImage *)image
{
  ASDN::MutexLocker l(_imageLock);
  if (_image != image) {
    _image = image;

    ASDN::MutexUnlocker u(_imageLock);
    ASDisplayNodePerformBlockOnMainThread(^{
      [self invalidateCalculatedSize];
      [self setNeedsDisplay];
    });
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

- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer;
{
  BOOL hasValidCropBounds = _cropEnabled && !CGRectIsNull(_cropDisplayBounds) && !CGRectIsEmpty(_cropDisplayBounds);

  return [[_ASImageNodeDrawParameters alloc] initWithCrop:_cropEnabled
                                                   opaque:self.opaque
                                                    image:self.image
                                                   bounds:(hasValidCropBounds ? _cropDisplayBounds : self.bounds)
                                            contentsScale:self.contentsScaleForDisplay
                                          backgroundColor:self.backgroundColor
                                              contentMode:self.contentMode
                                                 cropRect:self.cropRect
                                   imageModificationBlock:self.imageModificationBlock];
}

+ (UIImage *)displayWithParameters:(_ASImageNodeDrawParameters *)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelled
{
  UIImage *image = parameters.image;

  if (!image) {
    return nil;
  }

  ASDisplayNodeAssert(parameters.contentsScale > 0, @"invalid contentsScale at display time");

  // if the image is resizable, bail early since the image has likely already been configured
  BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(image.capInsets, UIEdgeInsetsZero);
  if (stretchable) {
    if (parameters.imageModificationBlock != NULL) {
      image = parameters.imageModificationBlock(image);
    }
    return image;
  }

  CGRect bounds = parameters.bounds;

  CGFloat contentsScale = parameters.contentsScale;
  UIViewContentMode contentMode = parameters.contentMode;
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
  if (!parameters.cropEnabled || !contentModeSupported || stretchable) {
    backingSize = imageSizeInPixels;
    imageDrawRect = (CGRect){.size = backingSize};
  } else {
    ASCroppedImageBackingSizeAndDrawRectInBounds(imageSizeInPixels,
                                                 boundsSizeInPixels,
                                                 contentMode,
                                                 parameters.cropRect,
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
  UIGraphicsBeginImageContextWithOptions(backingSize, parameters.opaque, 1.0);

  [image drawInRect:imageDrawRect];

  if (isCancelled()) {
    UIGraphicsEndImageContext();
    return nil;
  }

  UIImage *result = UIGraphicsGetImageFromCurrentImageContext();

  UIGraphicsEndImageContext();

  if (parameters.imageModificationBlock != NULL) {
    result = parameters.imageModificationBlock(result);
  }

  return result;
}

- (void)displayDidFinish
{
  [super displayDidFinish];

  // If we've got a block to perform after displaying, do it.
  if (self.image && _displayCompletionBlock) {

    // FIXME: _displayCompletionBlock is not protected by lock
    _displayCompletionBlock(NO);
    _displayCompletionBlock = nil;
  }
}

#pragma mark -
- (void)setNeedsDisplayWithCompletion:(void (^)(BOOL canceled))displayCompletionBlock
{
  if (self.displaySuspended) {
    if (displayCompletionBlock)
      displayCompletionBlock(YES);
    return;
  }

  // Stash the block and call-site queue. We'll invoke it in -displayDidFinish.
  // FIXME: _displayCompletionBlock not protected by lock
  if (_displayCompletionBlock != displayCompletionBlock) {
    _displayCompletionBlock = [displayCompletionBlock copy];
  }

  [self setNeedsDisplay];
}

#pragma mark - Cropping
- (BOOL)isCropEnabled
{
  return _cropEnabled;
}

- (void)setCropEnabled:(BOOL)cropEnabled
{
  [self setCropEnabled:cropEnabled recropImmediately:NO inBounds:self.bounds];
}

- (void)setCropEnabled:(BOOL)cropEnabled recropImmediately:(BOOL)recropImmediately inBounds:(CGRect)cropBounds
{
  if (_cropEnabled == cropEnabled)
    return;

  _cropEnabled = cropEnabled;
  _cropDisplayBounds = cropBounds;

  // If we have an image to display, display it, respecting our recrop flag.
  if (self.image)
  {
    ASDisplayNodePerformBlockOnMainThread(^{
      if (recropImmediately)
        [self displayImmediately];
      else
        [self setNeedsDisplay];
    });
  }
}

- (CGRect)cropRect
{
  return _cropRect;
}

- (void)setCropRect:(CGRect)cropRect
{
  if (CGRectEqualToRect(_cropRect, cropRect))
    return;

  _cropRect = cropRect;

  // TODO: this logic needs to be updated to respect cropRect.
  CGSize boundsSize = self.bounds.size;
  CGSize imageSize = self.image.size;

  BOOL isCroppingImage = ((boundsSize.width < imageSize.width) || (boundsSize.height < imageSize.height));

  // Re-display if we need to.
  ASDisplayNodePerformBlockOnMainThread(^{
    if (self.nodeLoaded && self.contentMode == UIViewContentModeScaleAspectFill && isCroppingImage)
      [self setNeedsDisplay];
  });
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

