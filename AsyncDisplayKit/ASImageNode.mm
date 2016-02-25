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

#if TARGET_OS_TV
  //tvOS
  BOOL isDefaultState;
#endif
  
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

    ASDN::MutexUnlocker u(_imageLock);
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

  _imageLock.lock();
    void (^displayCompletionBlock)(BOOL canceled) = _displayCompletionBlock;
    UIImage *image = _image;
  _imageLock.unlock();
  
  // If we've got a block to perform after displaying, do it.
  if (image && displayCompletionBlock) {

    displayCompletionBlock(NO);

    _imageLock.lock();
      _displayCompletionBlock = nil;
    _imageLock.unlock();
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


#if TARGET_OS_TV
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];
  isDefaultState = NO;
  UIView *view = [self getView];
  CALayer *layer = view.layer;

  CGSize targetShadowOffset = CGSizeMake(0.0, self.bounds.size.height/8);
  [layer removeAllAnimations];
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    layer.shadowOffset = targetShadowOffset;
  }];
  
  CABasicAnimation *shadowOffsetAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOffset"];
  shadowOffsetAnimation.toValue = [NSValue valueWithCGSize:targetShadowOffset];
  shadowOffsetAnimation.duration = 0.4;
  shadowOffsetAnimation.removedOnCompletion = NO;
  shadowOffsetAnimation.fillMode = kCAFillModeForwards;
  shadowOffsetAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeOut"];
  [layer addAnimation:shadowOffsetAnimation forKey:@"shadowOffset"];
  [CATransaction commit];
  
  CABasicAnimation *shadowOpacityAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
  shadowOpacityAnimation.toValue = [NSNumber numberWithFloat:0.45];
  shadowOpacityAnimation.duration = 0.4;
  shadowOpacityAnimation.removedOnCompletion = false;
  shadowOpacityAnimation.fillMode = kCAFillModeForwards;
  shadowOpacityAnimation.timingFunction = [CAMediaTimingFunction functionWithName:@"easeOut"];
  [layer addAnimation:shadowOpacityAnimation forKey:@"shadowOpacityAnimation"];
  
  view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25);
  
  [CATransaction commit];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
  [super touchesMoved:touches withEvent:event];

  if (!isDefaultState) {
    UIView *view = [self getView];

    UITouch *touch = [touches anyObject];
    // Get the specific point that was touched
    // This is quite messy in it's current state so is not ready for production. The reason it is here is for others to contribute and to make it clear what is occuring.
    // TODO: Clean up, and improve visuals.
    CGPoint point = [touch locationInView:self.view];
    float pitch = 0;
    float yaw = 0;
    BOOL topHalf = NO;
    if (point.y > CGRectGetHeight(self.view.frame)) {
      pitch = 15;
    } else if (point.y < -CGRectGetHeight(self.view.frame)) {
      pitch = -15;
    } else {
      pitch = (point.y/CGRectGetHeight(self.view.frame))*15;
    }
    if (pitch < 0) {
      topHalf = YES;
    }
    
    if (point.x > CGRectGetWidth(self.view.frame)) {
      yaw = 10;
    } else if (point.x < -CGRectGetWidth(self.view.frame)) {
      yaw = -10;
    } else {
      yaw = (point.x/CGRectGetWidth(self.view.frame))*10;
    }
    if (!topHalf) {
      if (yaw > 0) {
        yaw = -yaw;
      } else {
        yaw = fabsf(yaw);
      }
    }

    CATransform3D pitchTransform = CATransform3DMakeRotation([self degressToRadians:pitch],1.0,0.0,0.0);
    CATransform3D yawTransform = CATransform3DMakeRotation([self degressToRadians:yaw],0.0,1.0,0.0);
    CATransform3D transform = CATransform3DConcat(pitchTransform, yawTransform);
    CATransform3D scaleAndTransform = CATransform3DConcat(transform, CATransform3DMakeAffineTransform(CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25)));
    
    [UIView animateWithDuration:0.5 animations:^{
      view.layer.transform = scaleAndTransform;
    }];
  } else {
    [self setDefaultState];
  }
}


- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];
  [self finishTouches];
}

- (void)finishTouches
{
  if (!isDefaultState) {
    UIView *view = [self getView];
    CALayer *layer = view.layer;
    
    CGSize targetShadowOffset = CGSizeMake(0.0, self.bounds.size.height/8);
    CATransform3D targetScaleTransform = CATransform3DMakeScale(1.2, 1.2, 1.2);
    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
      layer.shadowOffset = targetShadowOffset;
    }];
    [CATransaction commit];
    
    [UIView animateWithDuration:0.4 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
      view.layer.transform = targetScaleTransform;
    } completion:^(BOOL finished) {
      if (finished) {
        [layer removeAnimationForKey:@"shadowOffset"];
        [layer removeAnimationForKey:@"shadowOpacity"];
      }
    }];
  } else {
    [self setDefaultState];
  }
}

- (void)setFocusedState
{
  UIView *view = [self getView];
  CALayer *layer = view.layer;
  layer.shadowOffset = CGSizeMake(2, 10);
  layer.shadowColor = [UIColor blackColor].CGColor;
  layer.shadowRadius = 12.0;
  layer.shadowOpacity = 0.45;
  layer.shadowPath = [UIBezierPath bezierPathWithRect:self.layer.bounds].CGPath;
  view.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1.25, 1.25);
}

- (void)setDefaultState
{
  UIView *view = [self getView];
  CALayer *layer = view.layer;
  view.transform = CGAffineTransformIdentity;
  layer.shadowOpacity = 0;
  layer.shadowOffset = CGSizeZero;
  layer.shadowRadius = 0;
  layer.shadowPath = nil;
  [layer removeAnimationForKey:@"shadowOffset"];
  [layer removeAnimationForKey:@"shadowOpacity"];
  isDefaultState = YES;
}

- (UIView *)getView
{
  UIView *view = self.view;
  //If we are inside a ASCellNode, then we need to apply our focus effects to the ASCellNode view/layer rather than the ASImageNode view/layer.
  if (CGSizeEqualToSize(self.view.superview.frame.size, self.view.frame.size) && self.view.superview.superview) {
    view = self.view.superview.superview;
  }
  return view;
}

- (float)degressToRadians:(float)value
{
  return value * M_PI / 180;
}

#endif

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

