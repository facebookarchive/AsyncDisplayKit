/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <pthread.h>

#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASThread.h>

@class ASLayoutSpec;

/**
 * The subclass header _ASDisplayNode+Subclasses_ defines the following methods that either must or can be overriden by
 * subclasses of ASDisplayNode.
 *
 * These methods should never be called directly by other classes.
 *
 * ## Drawing
 *
 * Implement one of +displayWithParameters:isCancelled: or +drawRect:withParameters:isCancelled: to provide
 * drawing for your node.
 *
 * Use -drawParametersForAsyncLayer: to copy any properties that are involved in drawing into an immutable object for
 * use on the display queue. The display and drawRect implementations *MUST* be thread-safe, as they can be called on
 * the displayQueue (asynchronously) or the main thread (synchronously/displayImmediately).
 *
 * Class methods that require passing in copies of the values are used to minimize the need for locking around instance
 * variable access, and the possibility of the asynchronous display pass grabbing an inconsistent state across multiple
 * variables.
 */

@interface ASDisplayNode (Subclassing)


/** @name View Configuration */


/**
 * @return The view class to use when creating a new display node instance. Defaults to _ASDisplayView.
 */
+ (Class)viewClass;


/** @name Properties */


/**
 * @abstract The scale factor to apply to the rendering.
 *
 * @discussion Use setNeedsDisplayAtScale: to set a value and then after display, the display node will set the layer's
 * contentsScale. This is to prevent jumps when re-rasterizing at a different contentsScale.
 * Read this property if you need to know the future contentsScale of your layer, eg in drawParameters.
 *
 * @see setNeedsDisplayAtScale:
 */
@property (nonatomic, assign, readonly) CGFloat contentsScaleForDisplay;

/**
 * @abstract Whether the view or layer of this display node is currently in a window
 */
@property (nonatomic, readonly, assign, getter=isInHierarchy) BOOL inHierarchy;

/**
 * @abstract Return the calculated layout.
 *
 * @discussion For node subclasses that implement manual layout (e.g., they have a custom -layout method), 
 * calculatedLayout may be accessed on subnodes to retrieved cached information about their size.  
 * This allows -layout to be very fast, saving time on the main thread.  
 * Note: .calculatedLayout will only be set for nodes that have had -measure: called on them.  
 * For manual layout, make sure you call -measure: in your implementation of -calculateSizeThatFits:.
 *
 * For node subclasses that use automatic layout (e.g., they implement -layoutSpecThatFits:), 
 * it is typically not necessary to use .calculatedLayout at any point.  For these nodes, 
 * the ASLayoutSpec implementation will automatically call -measureWithSizeRange: on all of the subnodes,
 * and the ASDisplayNode base class implementation of -layout will automatically make use of .calculatedLayout on the subnodes.
 *
 * @return Layout that wraps calculated size returned by -calculateSizeThatFits: (in manual layout mode),
 * or layout already calculated from layout spec returned by -layoutSpecThatFits: (in automatic layout mode).
 *
 * @warning Subclasses must not override this; it returns the last cached layout and is never expensive.
 */
@property (nonatomic, readonly, assign) ASLayout *calculatedLayout;

/** @name View Lifecycle */


/**
 * @abstract Called on the main thread immediately after self.view is created.
 *
 * @discussion This is the best time to add gesture recognizers to the view.
 */
- (void)didLoad ASDISPLAYNODE_REQUIRES_SUPER;


/** @name Layout */


/**
 * @abstract Called on the main thread by the view's -layoutSubviews.
 *
 * @discussion Subclasses override this method to layout all subnodes or subviews.
 */
- (void)layout;

/**
 * @abstract Called on the main thread by the view's -layoutSubviews, after -layout.
 *
 * @discussion Gives a chance for subclasses to perform actions after the subclass and superclass have finished laying
 * out.
 */
- (void)layoutDidFinish;


/** @name Layout calculation */

/**
 * @abstract Calculate a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion This method is called on a non-main thread. The default implementation calls either -layoutSpecThatFits: 
 * or -calculateSizeThatFits:, whichever method is overriden. Subclasses rarely need to override this method,
 * override -layoutSpecThatFits: or -calculateSizeThatFits: instead.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -measure: or -calculatedLayout instead.
 */
- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize;

/**
 * @abstract Return the calculated size.
 *
 * @param constrainedSize The maximum size the receiver should fit in.
 *
 * @discussion Subclasses that override should expect this method to be called on a non-main thread. The returned size
 * is wrapped in an ASLayout and cached for quick access during -layout. Other expensive work that needs to
 * be done before display can be performed here, and using ivars to cache any valuable intermediate results is
 * encouraged.
 *
 * @note Subclasses that override are committed to manual layout. Therefore, -layout: must be overriden to layout all subnodes or subviews.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -measure: or -calculatedLayout instead.
 */
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize;

/**
 * @abstract Return a layout spec that describes the layout of the receiver and its children.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @discussion Subclasses that override should expect this method to be called on a non-main thread. The returned layout spec
 * is used to calculate an ASLayout and cached by ASDisplayNode for quick access during -layout. Other expensive work that needs to
 * be done before display can be performed here, and using ivars to cache any valuable intermediate results is
 * encouraged.
 *
 * @note This method should not be called directly outside of ASDisplayNode; use -measure: or -calculatedLayout instead.
 */
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize;

/**
 * @abstract Invalidate previously measured and cached layout.
 *
 * @discussion Subclasses should call this method to invalidate the previously measured and cached layout for the display
 * node, when the contents of the node change in such a way as to require measuring it again.
 */
- (void)invalidateCalculatedLayout;


/** @name Drawing */


/**
 * @summary Delegate method to draw layer contents into a CGBitmapContext. The current UIGraphics context will be set
 * to an appropriate context.
 *
 * @param bounds Region to draw in.
 * @param parameters An object describing all of the properties you need to draw. Return this from
 * -drawParametersForAsyncLayer:
 * @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid
 * unnecessary work. A return value of YES means cancel drawing and return.
 * @param isRasterizing YES if the layer is being rasterized into another layer, in which case drawRect: probably wants
 * to avoid doing things like filling its bounds with a zero-alpha color to clear the backing store.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
+ (void)drawRect:(CGRect)bounds
  withParameters:(id<NSObject>)parameters
     isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock
   isRasterizing:(BOOL)isRasterizing;

/**
 * @summary Delegate override to provide new layer contents as a UIImage.
 *
 * @param parameters An object describing all of the properties you need to draw. Return this from
 * -drawParametersForAsyncLayer:
 * @param isCancelledBlock Execute this block to check whether the current drawing operation has been cancelled to avoid
 * unnecessary work. A return value of YES means cancel drawing and return.
 *
 * @return A UIImage with contents that are ready to display on the main thread. Make sure that the image is already
 * decoded before returning it here.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
+ (UIImage *)displayWithParameters:(id<NSObject>)parameters
                       isCancelled:(asdisplaynode_iscancelled_block_t)isCancelledBlock;

/**
 * @abstract Delegate override for drawParameters
 *
 * @param layer The layer that will be drawn into.
 *
 * @note Called on the main thread only
 */
- (NSObject *)drawParametersForAsyncLayer:(_ASDisplayLayer *)layer;

/**
 * @abstract Indicates that the receiver is about to display.
 *
 * @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) is
 * about to begin.
 */
- (void)displayWillStart ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver has finished displaying.
 *
 * @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) has
 * completed.
 */
- (void)displayDidFinish ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the node should fetch any external data, such as images.
 *
 * @discussion Subclasses may override this method to be notified when they should begin to fetch data. Fetching
 * should be done asynchronously. The node is also responsible for managing the memory of any data.
 * The data may be remote and accessed via the network, but could also be a local database query.
 */
- (void)fetchData ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver is about to display its subnodes. This method is not called if there are no
 * subnodes present.
 *
 * @param subnode The subnode of which display is about to begin.
 *
 * @discussion Subclasses may override this method to be notified when subnode display (asynchronous or synchronous) is
 * about to begin.
 */
- (void)subnodeDisplayWillStart:(ASDisplayNode *)subnode ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * @abstract Indicates that the receiver is finished displaying its subnodes. This method is not called if there are
 * no subnodes present.
 *
 * @param subnode The subnode of which display is about to completed.
 *
 * @discussion Subclasses may override this method to be notified when subnode display (asynchronous or synchronous) has
 * completed.
 */
- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode ASDISPLAYNODE_REQUIRES_SUPER;


/**
 * @abstract Marks the receiver's bounds as needing to be redrawn, with a scale value.
 *
 * @param contentsScale The scale at which the receiver should be drawn.
 *
 * @discussion Subclasses should override this if they don't want their contentsScale changed.
 *
 * @note This changes an internal property.
 * -setNeedsDisplay is also available to trigger display without changing contentsScaleForDisplay.
 * @see -setNeedsDisplay, contentsScaleForDisplay
 */
- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale;

/**
 * @abstract Recursively calls setNeedsDisplayAtScale: on subnodes.
 *
 * @param contentsScale The scale at which the receiver's subnode hierarchy should be drawn.
 *
 * @discussion Subclasses may override this if they require modifying the scale set on their child nodes.
 *
 * @note Only the node tree is walked, not the view or layer trees.
 *
 * @see setNeedsDisplayAtScale:
 * @see contentsScaleForDisplay
 */
- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale;


/** @name Touch handling */


/**
 * @abstract Tells the node when touches began in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;

/**
 * @abstract Tells the node when touches moved in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;

/**
 * @abstract Tells the node when touches ended in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;

/**
 * @abstract Tells the node when touches was cancelled in its view.
 *
 * @param touches A set of UITouch instances.
 * @param event A UIEvent associated with the touch.
 */
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;


/** @name Managing Gesture Recognizers */


/**
 * @abstract Asks the node if a gesture recognizer should continue tracking touches.
 *
 * @param gestureRecognizer A gesture recognizer trying to recognize a gesture.
 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;


/** @name Hit Testing */


/**
 * @abstract Returns the view that contains the point.
 *
 * @discussion Override to make this node respond differently to touches: (e.g. hide touches from subviews, send all
 * touches to certain subviews (hit area maximizing), etc.)
 *
 * @param point A point specified in the node's local coordinate system (bounds).
 * @param event The event that warranted a call to this method.
 *
 * @return Returns a UIView, not ASDisplayNode, for two reasons:
 * 1) allows sending events to plain UIViews that don't have attached nodes,
 * 2) hitTest: is never called before the views are created.
 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;


/** @name Observing node-related changes */


/**
 * Called just before the view is added to a superview.
 */
- (void)willEnterHierarchy ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Called after the view is removed from the window.
 */
- (void)didExitHierarchy ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Provides an opportunity to clear backing store and other memory-intensive intermediates, such as text layout managers
 * on the current node.
 *
 * @discussion Called by -recursivelyClearContents. Base class implements self.contents = nil, clearing any backing
 * store, for asynchronous regeneration when needed.
 */
- (void)clearContents ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Provides an opportunity to clear any fetched data (e.g. remote / network or database-queried) on the current node.
 *
 * @discussion This will not clear data recursively for all subnodes. Either call -recursivelyClearFetchedData or
 * selectively clear fetched data.
 */
- (void)clearFetchedData ASDISPLAYNODE_REQUIRES_SUPER;


/** @name Placeholders */

/**
 * @abstract Optionally provide an image to serve as the placeholder for the backing store while the contents are being
 * displayed.
 *
 * @discussion
 * Subclasses may override this method and return an image to use as the placeholder. Take caution as there may be a
 * time and place where this method is called on a background thread. Note that -[UIImage imageNamed:] is not thread
 * safe when using image assets.
 *
 * To retrieve the CGSize to do any image drawing, use the node's calculatedSize property.
 *
 * Defaults to nil.
 *
 * @note Called on the display queue and/or main queue (MUST BE THREAD SAFE)
 */
- (UIImage *)placeholderImage;


/** @name Description */


/**
 * @abstract Return a description of the node
 *
 * @discussion The function that gets called for each display node in -recursiveDescription
 */
- (NSString *)descriptionForRecursiveDescription;

@end

@interface ASDisplayNode (ASDisplayNodePrivate)
// This method has proven helpful in a few rare scenarios, similar to a category extension on UIView,
// but it's considered private API for now and its use should not be encouraged.
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass;
@end

#define ASDisplayNodeAssertThreadAffinity(viewNode)   ASDisplayNodeAssert(!viewNode || ASDisplayNodeThreadIsMain() || !(viewNode).nodeLoaded, @"Incorrect display node thread affinity")
#define ASDisplayNodeCAssertThreadAffinity(viewNode) ASDisplayNodeCAssert(!viewNode || ASDisplayNodeThreadIsMain() || !(viewNode).nodeLoaded, @"Incorrect display node thread affinity")
