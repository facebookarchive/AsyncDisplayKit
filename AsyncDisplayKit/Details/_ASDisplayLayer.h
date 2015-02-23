/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>


@class ASSentinel;
@protocol _ASDisplayLayerDelegate;

// Type for the cancellation checker block passed into the async display blocks. YES means the operation has been cancelled, NO means continue.
typedef BOOL(^asdisplaynode_iscancelled_block_t)(void);

@interface _ASDisplayLayer : CALayer

/**
 @summary Set to YES to enable asynchronous display for the receiver.

 @default YES (note that this might change for subclasses)
 */
@property (atomic, assign) BOOL displaysAsynchronously;

/**
 @summary Cancels any pending async display.

 @desc If the receiver has had display called and is waiting for the dispatched async display to be executed, this will
 cancel that dispatched async display.  This method is useful to call when removing the receiver from the window.
 */
- (void)cancelAsyncDisplay;

/**
 @summary The dispatch queue used for async display.

 @desc This is exposed here for tests only.
 */
+ (dispatch_queue_t)displayQueue;

@property (nonatomic, strong, readonly) ASSentinel *displaySentinel;

/**
 @summary Delegate for asynchronous display of the layer.

 @desc The asyncDelegate will have the opportunity to override the methods related to async display.
 */
@property (atomic, weak) id<_ASDisplayLayerDelegate> asyncDelegate;

/**
 @summary Suspends both asynchronous and synchronous display of the receiver if YES.

 @desc This can be used to suspend all display calls while the receiver is still in the view hierarchy.  If you
 want to just cancel pending async display, use cancelAsyncDisplay instead.

 @default NO
 */
@property (atomic, assign, getter=isDisplaySuspended) BOOL displaySuspended;

/**
 @summary Bypasses asynchronous rendering and performs a blocking display immediately on the current thread.

 @desc Used by ASDisplayNode to display the layer synchronously on-demand (must be called on the main thread).
 */
- (void)displayImmediately;

@end

/**
 Implement one of +displayAsyncLayer:parameters:isCancelled: or +drawRect:withParameters:isCancelled: to provide drawing for your node.
 Use -drawParametersForAsyncLayer: to copy any properties that are involved in drawing into an immutable object for use on the display queue.
 display/drawRect implementations MUST be thread-safe, as they can be called on the displayQueue (async) or the main thread (sync/displayImmediately)
 */
@protocol _ASDisplayLayerDelegate <NSObject>

@optional

// Called on the display queue and/or main queue (MUST BE THREAD SAFE)

/**
 @summary Delegate method to draw layer contents into a CGBitmapContext. The current UIGraphics context will be set to an appropriate context.
 @param parameters An object describing all of the properties you need to draw. Return this from -drawParametersForAsyncLayer:
 @param isCancelled Execute this block to check whether the current drawing operation has been cancelled to avoid unnecessary work. A return value of YES means cancel drawing and return.
 @param isRasterizing YES if the layer is being rasterized into another layer, in which case drawRect: probably wants to avoid doing things like filling its bounds with a zero-alpha color to clear the backing store.
 */
+ (void)drawRect:(CGRect)bounds withParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock isRasterizing:(BOOL)isRasterizing;

/**
 @summary Delegate override to provide new layer contents as a UIImage.
 @param parameters An object describing all of the properties you need to draw. Return this from -drawParametersForAsyncLayer:
 @param isCancelled Execute this block to check whether the current drawing operation has been cancelled to avoid unnecessary work. A return value of YES means cancel drawing and return.
 @return A UIImage with contents that are ready to display on the main thread. Make sure that the image is already decoded before returning it here.
 */
+ (UIImage *)displayWithParameters:(id<NSObject>)parameters isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock;

// Called on the main thread only

/**
 @summary Delegate override for drawParameters
 */
- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer;

/**
 @summary Delegate override for willDisplay
 */
- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer;

/**
 @summary Delegate override for didDisplay
 */
- (void)didDisplayAsyncLayer:(_ASDisplayLayer *)layer;

/**
 @summary Delegate callback to display a layer, synchronously or asynchronously.  'asyncLayer' does not necessarily need to exist (can be nil).  Typically, a delegate will display/draw its own contents and then set .contents on the layer when finished.
 */
- (void)displayAsyncLayer:(_ASDisplayLayer *)asyncLayer asynchronously:(BOOL)asynchronously;

/**
 @summary Delegate callback to handle a layer which requests its asynchronous display be cancelled.
 */
- (void)cancelDisplayAsyncLayer:(_ASDisplayLayer *)asyncLayer;

@end
