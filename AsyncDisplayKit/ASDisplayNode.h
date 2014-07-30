/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>

#import "_ASAsyncTransactionContainer.h"
#import "ASBaseDefines.h"

// Please also review ASDisplayNode+Subclasses.h if you are new to ASDisplayNode.

@interface ASDisplayNode : NSObject

// Designated initializer.  The ASDisplayNode's view will be a subclass that enables asynchronous rendering, and passes through -layout and touch handling methods.
- (id)init;

// Alternative initializer.  Provide any UIView subclass, such as UIScrollView, and the ASDisplayNode's view will be of that type.
// If viewClass is not a subclass of _ASDisplayView, it will still render synchronously and -layout and touch handling methods on the node will not be called.
// The view instance will be created with alloc/init.
- (id)initWithViewClass:(Class)viewClass;

// Alternative initializer.  Provide any CALayer subclass, such as CATransformLayer, and the ASDisplayNode's view will be of that type.
// If layerClass is not a subclass of _ASDisplayLayer, it will still render synchronously and -layout on the node will not be called.
// The layer instance will be created with alloc/init.
- (id)initWithLayerClass:(Class)layerClass;

// If this view is strictly synchronous (ie wraps a non _ASDisplayView view)
@property (nonatomic, readonly, assign, getter=isSynchronous) BOOL synchronous;

// The view property is lazily initialized, similar to UIViewController.
// The first access to it must be on the main thread, and should only be used on the main thread thereafter as well.
// To go the other direction, use ASViewToDisplayNode() in ASDisplayNodeExtras.h
@property (nonatomic, readonly, retain) UIView *view;
@property (atomic, readonly, assign, getter=isViewLoaded) BOOL viewLoaded;  // Also YES if isLayerBacked == YES && self.layer != nil.  Rename to isBackingLoaded?

// If this node does not have an associated view, instead relying directly upon a layer
@property (nonatomic, assign, getter=isLayerBacked) BOOL layerBacked;
// The same restrictions apply as documented above about the view property. To go the other direction, use ASLayerToDisplayNode() in ASDisplayNodeExtras.h
@property (nonatomic, readonly, retain) CALayer *layer;

// Subclasses must not override this; it caches results from -calculateSizeThatFits:.  Calling this method may be expensive if result is not cached.
// Though this method does not set the bounds of the view, it does have side effects--caching both the constraint and the result.
- (CGSize)sizeToFit:(CGSize)constrainedSize;

// Subclasses must not override this; it returns the last cached size calculated and is never expensive.  Ideal for use by subclasses in -layout, having already
// prompted their subnodes to calculate their size by calling -sizeToFit: on them in -calculateSizeThatFits:
@property (nonatomic, readonly, assign) CGSize calculatedSize;

@property (nonatomic, readonly, assign) CGSize constrainedSizeForCalulatedSize;

// Add a node as a subnode to this node. The subnode's view will automatically be added to this node's view automaically, lazily if the views are not created yet.
- (void)addSubnode:(ASDisplayNode *)subnode;

// Insert a subnode before a given subnode in the list. If the views are loaded, the subnode's view will be inserted below the given node's view in the hierarchy even if there are other non-displaynode views.
- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below;

// Insert a subnode after a given subnode in the list. If the views are loaded, the subnode's view will be inserted above the given node's view in the hierarchy even if there are other non-displaynode views.
- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)below;

// Insert a subnode at a given index in subnodes. If this node's view is loaded, ASDisplayNode insert the subnode's view after the subnode at index - 1's view even if there are other non-displaynode views.
- (void)insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx;

/**
 Replace subnode with replacementSubnode.

 If subnode is not a subnode of self, this method will throw an exception
 If replacementSubnode is nil, this method will throw an exception
 Should both subnode and replacementSubnode already be subnodes of self, subnode is removed and replacementSubnode inserted in its place.
 @param subnode a subnode of self
 @param replacementSubnode a node with which to replace subnode
 */
- (void)replaceSubnode:(ASDisplayNode *)subnode withSubnode:(ASDisplayNode *)replacementSubnode;

/**
 Add a subnode, but have it size asynchronously on a background queue.
 @param subnode The unsized subnode to insert into the view hierarchy
 @param completion The completion callback will be called on the main queue after the subnode has been inserted in place of the placeholder.
 @return  A placeholder node is inserted into the hierarchy where the node will be. The placeholder can be moved around in the hiercharchy while the view is sizing. Once sizing is complete on the background queue, this placeholder will be removed and the
 */
- (ASDisplayNode *)addSubnodeAsynchronously:(ASDisplayNode *)subnode
                              completion:(void(^)(ASDisplayNode *replacement))completion;

- (void)replaceSubnodeAsynchronously:(ASDisplayNode *)subnode
                            withNode:(ASDisplayNode *)replacementSubnode
                          completion:(void(^)(BOOL cancelled, ASDisplayNode *replacement, ASDisplayNode *oldSubnode))completion;

// Remove this node from its supernode.  The node's view will be automatically removed from the supernode's view.
- (void)removeFromSupernode;

// Access to the subnodes of this node, and the supernode of this node.
@property (nonatomic, readonly, retain) NSArray *subnodes;
@property (nonatomic, readonly, assign) ASDisplayNode *supernode;

// Called just before the view is added to a superview.
// TODO rename these to the UIView selectors, willMoveToSuperview etc
- (void)willAppear;

// Called after the view is removed from the window
- (void)willDisappear;

// Called after the view is removed from the window
- (void)didDisappear;

/**
 @abstract
 Set whether this node's view performs asynchronous rendering. Defaults to YES, except
 for synchronous views (ie, those created with -initWithViewClass: / -initWithLayerClass:), which are always NO

 @discussion
 If this flag is set, then the node will participate in the current asyncdisplaykit_async_transaction and do its rendering on the displayQueue instead of the main thread.
 Asynchronous rendering proceeds as follows:

   When the view is initially added to the hierarchy, it has -needsDisplay true.
   After layout, Core Animation will call -display on the _ASDisplayLayer
   -display enqueues a rendering operation on the displayQueue
   When the render block executes, it calls the delegate display method (-drawRect:... or -display)
   The delegate provides contents via this method and an operation is added to the asyncdisplaykit_async_transaction
   Once all rendering is complete for the current asyncdisplaykit_async_transaction,
   the completion for the block sets the contents on all of the layers in the same frame

 If asynchronous rendering is disabled:

   When the view is initially added to the hierarchy, it has -needsDisplay true.
   After layout, Core Animation will call -display on the _ASDisplayLayer
   -display calls  delegate display method (-drawRect:... or -display) immediately
   -display sets the layer contents immediately with the result

 Note: this has nothing to do with CALayer@drawsAsynchronously
 */
@property (nonatomic, assign) BOOL displaysAsynchronously;

/**
 @abstract
 When set to YES, causes all descendant nodes' layers/views to be drawn directly into this node's layer/view's backing store.  Defaults to NO.

 @discussion
 If a node's descendants are static (never animated or never change attributes after creation) then that node is a good candidate for rasterization.  Rasterizing descendants has two main benefits:
 1) Backing stores for descendant layers are not created.  Instead the layers are drawn directly into the rasterized container.  This can save a great deal of memory.
 2) Since the entire subtree is drawn into one backing store, compositing and blending are eliminated in that subtree which can help improve animation/scrolling/etc performance.

 Rasterization does not currently support descendants with transform, sublayerTransform, or alpha.  Those properties will be ignored when rasterizing descendants.

 Note: this has nothing to do with -[CALayer shouldRasterize], which doesn't work with ASDisplayNode's asynchronous rendering model.
 */
@property (nonatomic, assign) BOOL shouldRasterizeDescendants;

// Call this to display the node's view/layer immediately on the current thread, bypassing the background thread rendering.
- (void)displayImmediately;

// Set this to YES to prevent the node's layer from displaying.  A subclass may check this flag during -display or -drawInContext: to cancel a display
// that is already in progress.  See -displayWasCancelled.
// If a setNeedsDisplay occurs while preventOrCancelDisplay is YES, and preventOrCancelDisplay is set to NO, then the layer will be automatically
// displayed.  Defaults to NO.  Does not control display for any child or descendant nodes; for that, use -recursiveSetPreventOrCancelDisplay:.
@property (nonatomic, assign) BOOL preventOrCancelDisplay;

// Same as 'preventOrCancelDisplay' but also affects all child and descendant nodes.
- (void)recursiveSetPreventOrCancelDisplay:(BOOL)flag;

// When set to a non-zero inset, increases the bounds for hit testing to make it easier to tap or perform gestures on this node.  Default is UIEdgeInsetsZero.
// This affects the default implementation of -hitTest and -pointInside, so subclasses should call super if you override it and want hitTestSlop applied.
@property (nonatomic, assign) UIEdgeInsets hitTestSlop;

// Helper method for computing whether a point falls within the node's bounds.  Includes the "slop" factor specified with hitTestSlop.
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event;

// Coordinate space mapping that works before UIView instantiation
- (CGPoint)convertPoint:(CGPoint)point toNode:(ASDisplayNode *)node;
- (CGPoint)convertPoint:(CGPoint)point fromNode:(ASDisplayNode *)node;
- (CGRect)convertRect:(CGRect)rect toNode:(ASDisplayNode *)node;
- (CGRect)convertRect:(CGRect)rect fromNode:(ASDisplayNode *)node;

@end

@interface ASDisplayNode (Debugging)

// A nice way to print your view hieararchy for debugging: (lldb) po [node recursiveDescription]
- (NSString *)displayNodeRecursiveDescription;

@end

//
// The following properties and methods provide thread-safe access to traditionally unsafe UIView and CALayer functionality.
// Using them will not cause the actual view/layer to be created, and will be applied when it is created (when the view or layer property is accessed).
// After the view is created, the properties pass through to the view directly as if called on the main thread.
// See UIView.h and CALayer.h for documentation on these common properties.
//

@interface ASDisplayNode (UIViewBridge)

- (void)setNeedsDisplay;    // Marks the view as needing display.  Convenience for use whether view is created or not, or from a background thread.
- (void)setNeedsLayout;     // Marks the view as needing layout.   Convenience for use whether view is created or not, or from a background thread.

@property (atomic, retain)           id contents;                    // default=nil
@property (atomic, assign)           BOOL clipsToBounds;             // default==NO
@property (atomic, getter=isOpaque)  BOOL opaque;                    // default==YES

@property (atomic, assign)           BOOL allowsEdgeAntialiasing;
@property (atomic, assign)           unsigned int edgeAntialiasingMask; // default==all values from CAEdgeAntialiasingMask

@property (atomic, getter=isHidden)  BOOL hidden;                    // default==NO
@property (atomic, assign)           BOOL needsDisplayOnBoundsChange;// default==NO
@property (atomic, assign)           BOOL autoresizesSubviews;       // default==YES (undefined for layer-backed nodes)
@property (atomic, assign)           UIViewAutoresizing autoresizingMask; // default==UIViewAutoresizingNone  (undefined for layer-backed nodes)
@property (atomic, assign)           CGFloat alpha;                  // default=1.0f
@property (atomic, assign)           CGRect bounds;                  // default=CGRectZero
@property (atomic, assign)           CGRect frame;                   // default=CGRectZero
@property (atomic, assign)           CGPoint anchorPoint;            // default={0.5, 0.5}
@property (atomic, assign)           CGFloat zPosition;              // default=0.0
@property (atomic, assign)           CGPoint position;               // default=CGPointZero
@property (atomic, assign)           CGFloat contentsScale;          // default=1.0f. See @contentsScaleForDisplay for more info
@property (atomic, assign)           CATransform3D transform;        // default=CATransform3DIdentity
@property (atomic, assign)           CATransform3D subnodeTransform; // default=CATransform3DIdentity
@property (atomic, copy)             NSString *name;                 // default=nil. Use this to tag your layers in the server-recurse-description / pca or for your own purposes

/**
 In contrast to UIView, setting a transparent color will not set opaque = NO.
 This only affects nodes that implement +drawRect like ASTextNode
*/
@property (atomic, retain)           UIColor *backgroundColor;       // default=nil
/**
 This is like UIView's contentMode property, but better. We do our own mapping to layer.contentsGravity in _ASDisplayView you can set needsDisplayOnBoundsChange independently. Thus, UIViewContentModeRedraw is not allowed; use needsDisplayOnBoundsChange = YES instead, and pick an appropriate contentMode for your content while it's being re-rendered.
 */
@property (atomic, assign)           UIViewContentMode contentMode;  // default=UIViewContentModeScaleToFill

@property (atomic, assign, getter=isUserInteractionEnabled) BOOL userInteractionEnabled; // default=YES (NO for layer-backed nodes)
@property (atomic, assign, getter=isExclusiveTouch) BOOL exclusiveTouch;     // default=NO
@property (atomic, assign)           CGColorRef shadowColor;         // default=opaque rgb black
@property (atomic, assign)           CGFloat shadowOpacity;          // default=0.0
@property (atomic, assign)           CGSize shadowOffset;            // default=(0, -3)
@property (atomic, assign)           CGFloat shadowRadius;           // default=3
@property (atomic, assign)           CGFloat borderWidth;            // default=0
@property (atomic, assign)           CGColorRef borderColor;         // default=opaque rgb black


/**
 Accessibility support
 */
@property (atomic, assign)           BOOL isAccessibilityElement;
@property (atomic, copy)             NSString *accessibilityLabel;
@property (atomic, copy)             NSString *accessibilityHint;
@property (atomic, copy)             NSString *accessibilityValue;
@property (atomic, assign)           UIAccessibilityTraits accessibilityTraits;
@property (atomic, assign)           CGRect accessibilityFrame;
@property (atomic, retain)           NSString *accessibilityLanguage;
@property (atomic, assign)           BOOL accessibilityElementsHidden;
@property (atomic, assign)           BOOL accessibilityViewIsModal;
@property (atomic, assign)           BOOL shouldGroupAccessibilityChildren;

@end

/*
 ASDisplayNode participates in ASAsyncTransactions, so you can determine when your subnodes are done rendering.
 See: -(void)asyncdisplaykit_asyncTransactionContainerStateDidChange in ASDisplayNodeSubclass.h
 */
@interface ASDisplayNode (ASDisplayNodeAsyncTransactionContainer) <ASDisplayNodeAsyncTransactionContainer>
@end
