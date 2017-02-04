//
//  ASImageNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASControlNode.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ASAnimatedImageProtocol;

/**
 * Image modification block.  Use to transform an image before display.
 *
 * @param image The image to be displayed.
 *
 * @return A transformed image.
 */
typedef UIImage * _Nullable (^asimagenode_modification_block_t)(UIImage *image);


/**
 * @abstract Draws images.
 * @discussion Supports cropping, tinting, and arbitrary image modification blocks.
 */
@interface ASImageNode : ASControlNode

/**
 * @abstract The image to display.
 *
 * @discussion The node will efficiently display stretchable images by using
 * the layer's contentsCenter property.  Non-stretchable images work too, of
 * course.
 */
@property (nullable, nonatomic, strong) UIImage *image;

/**
 @abstract The placeholder color.
 */
@property (nullable, nonatomic, strong) UIColor *placeholderColor;

/**
 * @abstract Indicates whether efficient cropping of the receiver is enabled.
 *
 * @discussion Defaults to YES. See -setCropEnabled:recropImmediately:inBounds: for more
 * information.
 */
@property (nonatomic, assign, getter=isCropEnabled) BOOL cropEnabled;

/**
 * @abstract Indicates that efficient downsizing of backing store should *not* be enabled.
 *
 * @discussion Defaults to NO. @see ASCroppedImageBackingSizeAndDrawRectInBounds for more
 * information.
 */
@property (nonatomic, assign) BOOL forceUpscaling;

/**
 * @abstract Forces image to be rendered at forcedSize.
 * @discussion Defaults to CGSizeZero to indicate that the forcedSize should not be used.
 * Setting forcedSize to non-CGSizeZero will force the backing of the layer contents to 
 * be forcedSize (automatically adjusted for contentsSize).
 */
@property (nonatomic, assign) CGSize forcedSize;

/**
 * @abstract Enables or disables efficient cropping.
 * 
 * @param cropEnabled YES to efficiently crop the receiver's contents such that
 * contents outside of its bounds are not included; NO otherwise.
 *
 * @param recropImmediately If the receiver has an image, YES to redisplay the
 * receiver immediately; NO otherwise.
 *
 * @param cropBounds The bounds into which the receiver will be cropped. Useful
 * if bounds are to change in response to cropping (but have not yet done so).
 *
 * @discussion Efficient cropping is only performed when the receiver's view's
 * contentMode is UIViewContentModeScaleAspectFill. By default, cropping is
 * enabled. The crop alignment may be controlled via cropAlignmentFactor.
 */
- (void)setCropEnabled:(BOOL)cropEnabled recropImmediately:(BOOL)recropImmediately inBounds:(CGRect)cropBounds;

/**
 * @abstract A value that controls how the receiver's efficient cropping is aligned.
 *
 * @discussion This value defines a rectangle that is to be featured by the
 * receiver. The rectangle is specified as a "unit rectangle," using
 * fractions of the source image's width and height, e.g. CGRectMake(0.5, 0,
 * 0.5, 1.0) will feature the full right half a photo. If the cropRect is
 * empty, the content mode of the receiver will be used to determine its
 * dimensions, and only the cropRect's origin will be used for positioning. The
 * default value of this property is CGRectMake(0.5, 0.5, 0.0, 0.0).
 */
@property (nonatomic, readwrite, assign) CGRect cropRect;

/**
 * @abstract An optional block which can perform drawing operations on image
 * during the display phase.
 *
 * @discussion Can be used to add image effects (such as rounding, adding
 * borders, or other pattern overlays) without extraneous display calls.
 */
@property (nullable, nonatomic, readwrite, copy) asimagenode_modification_block_t imageModificationBlock;

/**
 * @abstract Marks the receiver as needing display and performs a block after
 * display has finished.
 *
 * @param displayCompletionBlock The block to be performed after display has
 * finished.  Its `canceled` property will be YES if display was prevented or
 * canceled (via displaySuspended); NO otherwise.
 * 
 * @discussion displayCompletionBlock will be performed on the main-thread. If
 * `displaySuspended` is YES, `displayCompletionBlock` is will be
 * performed immediately and `YES` will be passed for `canceled`.
 */
- (void)setNeedsDisplayWithCompletion:(nullable void (^)(BOOL canceled))displayCompletionBlock;

#if TARGET_OS_TV
/** 
 * A bool to track if the current appearance of the node
 * is the default focus appearance.
 * Exposed here so the category methods can set it.
 */
@property (nonatomic, assign) BOOL isDefaultFocusAppearance;
#endif

@end

@interface ASImageNode (AnimatedImage)

/**
 * @abstract The animated image to playback
 *
 * @discussion Set this to an object which conforms to ASAnimatedImageProtocol
 * to have the ASImageNode playback an animated image.
 */
@property (nullable, nonatomic, strong) id <ASAnimatedImageProtocol> animatedImage;

/**
 * @abstract Pause the playback of an animated image.
 *
 * @discussion Set to YES to pause playback of an animated image and NO to resume
 * playback.
 */
@property (nonatomic, assign) BOOL animatedImagePaused;

/**
 * @abstract The runloop mode used to animate the image.
 *
 * @discussion Defaults to NSRunLoopCommonModes. Another commonly used mode is NSDefaultRunLoopMode.
 * Setting NSDefaultRunLoopMode will cause animation to pause while scrolling (if the ASImageNode is
 * in a scroll view), which may improve scroll performance in some use cases.
 */
@property (nonatomic, strong) NSString *animatedImageRunLoopMode;

@end

@interface ASImageNode (Unavailable)

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock AS_UNAVAILABLE();

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock AS_UNAVAILABLE();

@end

ASDISPLAYNODE_EXTERN_C_BEGIN

/**
 * @abstract Image modification block that rounds (and optionally adds a border to) an image.
 *
 * @param borderWidth The width of the round border to draw, or zero if no border is desired.
 * @param borderColor What colour border to draw.
 *
 * @see <imageModificationBlock>
 *
 * @return An ASImageNode image modification block.
 */
asimagenode_modification_block_t ASImageNodeRoundBorderModificationBlock(CGFloat borderWidth, UIColor * _Nullable borderColor);

/**
 * @abstract Image modification block that applies a tint color à la UIImage configured with
 * renderingMode set to UIImageRenderingModeAlwaysTemplate.
 *
 * @param color The color to tint the image.
 *
 * @see <imageModificationBlock>
 *
 * @return An ASImageNode image modification block.
 */
asimagenode_modification_block_t ASImageNodeTintColorModificationBlock(UIColor *color);

ASDISPLAYNODE_EXTERN_C_END
NS_ASSUME_NONNULL_END
