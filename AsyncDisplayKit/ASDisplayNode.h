//
//  ASDisplayNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>

#import <AsyncDisplayKit/_ASAsyncTransactionContainer.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASDealloc2MainObject.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASAsciiArtBoxCreator.h>
#import <AsyncDisplayKit/ASLayoutable.h>

@class ASDisplayNode;

/**
 * UIView creation block. Used to create the backing view of a new display node.
 */
typedef UIView * _Nonnull(^ASDisplayNodeViewBlock)();

/**
 * UIView creation block. Used to create the backing view of a new display node.
 */
typedef UIViewController * _Nonnull(^ASDisplayNodeViewControllerBlock)();

/**
 * CALayer creation block. Used to create the backing layer of a new display node.
 */
typedef CALayer * _Nonnull(^ASDisplayNodeLayerBlock)();

/**
 * ASDisplayNode loaded callback block. This block is called BEFORE the -didLoad method and is always called on the main thread.
 */
typedef void (^ASDisplayNodeDidLoadBlock)(ASDisplayNode * _Nonnull node);

/**
 * ASDisplayNode will / did render node content in context.
 */
typedef void (^ASDisplayNodeContextModifier)(_Nonnull CGContextRef context);

/**
 * ASDisplayNode layout spec block. This block can be used instead of implementing layoutSpecThatFits: in subclass
 */
typedef ASLayoutSpec * _Nonnull(^ASLayoutSpecBlock)(ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize);

/**
 Interface state is available on ASDisplayNode and ASViewController, and
 allows checking whether a node is in an interface situation where it is prudent to trigger certain
 actions: measurement, data fetching, display, and visibility (the latter for animations or other onscreen-only effects).
 */

typedef NS_OPTIONS(NSUInteger, ASInterfaceState)
{
  /** The element is not predicted to be onscreen soon and preloading should not be performed */
  ASInterfaceStateNone          = 0,
  /** The element may be added to a view soon that could become visible.  Measure the layout, including size calculation. */
  ASInterfaceStateMeasureLayout = 1 << 0,
  /** The element is likely enough to come onscreen that disk and/or network data required for display should be fetched. */
  ASInterfaceStateFetchData     = 1 << 1,
  /** The element is very likely to become visible, and concurrent rendering should be executed for any -setNeedsDisplay. */
  ASInterfaceStateDisplay       = 1 << 2,
  /** The element is physically onscreen by at least 1 pixel.
   In practice, all other bit fields should also be set when this flag is set. */
  ASInterfaceStateVisible       = 1 << 3,

  /**
   * The node is not contained in a cell but it is in a window.
   *
   * Currently we only set `interfaceState` to other values for
   * nodes contained in table views or collection views.
   */
  ASInterfaceStateInHierarchy   = ASInterfaceStateMeasureLayout | ASInterfaceStateFetchData | ASInterfaceStateDisplay | ASInterfaceStateVisible,
};

/**
 * Default drawing priority for display node
 */
extern NSInteger const ASDefaultDrawingPriority;

/**
 * An `ASDisplayNode` is an abstraction over `UIView` and `CALayer` that allows you to perform calculations about a view
 * hierarchy off the main thread, and could do rendering off the main thread as well.
 *
 * The node API is designed to be as similar as possible to `UIView`. See the README for examples.
 *
 * ## Subclassing
 *
 * `ASDisplayNode` can be subclassed to create a new UI element. The subclass header `ASDisplayNode+Subclasses` provides
 * necessary declarations and conveniences.
 *
 * Commons reasons to subclass includes making a `UIView` property available and receiving a callback after async
 * display.
 *
 */

NS_ASSUME_NONNULL_BEGIN
@interface ASDisplayNode : ASDealloc2MainObject <ASLayoutable>


/** @name Initializing a node object */


/** 
 * @abstract Designated initializer.
 *
 * @return An ASDisplayNode instance whose view will be a subclass that enables asynchronous rendering, and passes 
 * through -layout and touch handling methods.
 */
- (instancetype)init;


/**
 * @abstract Alternative initializer with a block to create the backing view.
 *
 * @param viewBlock The block that will be used to create the backing view.
 *
 * @return An ASDisplayNode instance that loads its view with the given block that is guaranteed to run on the main
 * queue. The view will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock;

/**
 * @abstract Alternative initializer with a block to create the backing view.
 *
 * @param viewBlock The block that will be used to create the backing view.
 * @param didLoadBlock The block that will be called after the view created by the viewBlock is loaded
 *
 * @return An ASDisplayNode instance that loads its view with the given block that is guaranteed to run on the main
 * queue. The view will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock;

/**
 * @abstract Alternative initializer with a block to create the backing layer.
 *
 * @param layerBlock The block that will be used to create the backing layer.
 *
 * @return An ASDisplayNode instance that loads its layer with the given block that is guaranteed to run on the main
 * queue. The layer will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock;

/**
 * @abstract Alternative initializer with a block to create the backing layer.
 *
 * @param layerBlock The block that will be used to create the backing layer.
 * @param didLoadBlock The block that will be called after the layer created by the layerBlock is loaded
 *
 * @return An ASDisplayNode instance that loads its layer with the given block that is guaranteed to run on the main
 * queue. The layer will render synchronously and -layout and touch handling methods on the node will not be called.
 */
- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(nullable ASDisplayNodeDidLoadBlock)didLoadBlock;


/** @name Properties */

/**
 * @abstract The name of this node, which will be displayed in `description`. The default value is nil.
 */
@property (nullable, atomic, copy) NSString *name;

/** 
 * @abstract Returns whether the node is synchronous.
 *
 * @return NO if the node wraps a _ASDisplayView, YES otherwise.
 */
@property (nonatomic, readonly, assign, getter=isSynchronous) BOOL synchronous;


/** @name Getting view and layer */

/** 
 * @abstract Returns a view.
 *
 * @discussion The view property is lazily initialized, similar to UIViewController. 
 * To go the other direction, use ASViewToDisplayNode() in ASDisplayNodeExtras.h.
 *
 * @warning The first access to it must be on the main thread, and should only be used on the main thread thereafter as 
 * well.
 */
@property (nonatomic, readonly, strong) UIView *view;

/** 
 * @abstract Returns whether a node's backing view or layer is loaded.
 *
 * @return YES if a view is loaded, or if layerBacked is YES and layer is not nil; NO otherwise.
 */
@property (atomic, readonly, assign, getter=isNodeLoaded) BOOL nodeLoaded;

/** 
 * @abstract Returns whether the node rely on a layer instead of a view.
 *
 * @return YES if the node rely on a layer, NO otherwise.
 */
@property (nonatomic, assign, getter=isLayerBacked) BOOL layerBacked;

/** 
 * @abstract Returns a layer.
 *
 * @discussion The layer property is lazily initialized, similar to the view property.
 * To go the other direction, use ASLayerToDisplayNode() in ASDisplayNodeExtras.h.
 *
 * @warning The first access to it must be on the main thread, and should only be used on the main thread thereafter as 
 * well.
 */
@property (nonatomic, readonly, strong) CALayer * _Nonnull layer;

/**
 * @abstract Returns the Interface State of the node.
 *
 * @return The current ASInterfaceState of the node, indicating whether it is visible and other situational properties.
 *
 * @see ASInterfaceState
 */
@property (nonatomic, readonly) ASInterfaceState interfaceState;


/** @name Managing dimensions */

/**
 * @abstract Asks the node to measure and return the size that best fits its subnodes.
 *
 * @param constrainedSize The maximum size the receiver should fit in.
 *
 * @return A new size that fits the receiver's subviews.
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the 
 * constraint and the result.
 *
 * @warning Subclasses must not override this; it calls -measureWithSizeRange: with zero min size. 
 * -measureWithSizeRange: caches results from -calculateLayoutThatFits:.  Calling this method may 
 * be expensive if result is not cached.
 *
 * @see measureWithSizeRange:
 * @see [ASDisplayNode(Subclassing) calculateLayoutThatFits:]
 */
- (CGSize)measure:(CGSize)constrainedSize;

/**
 * @abstract Asks the node to measure a layout based on given size range.
 *
 * @param constrainedSize The minimum and maximum sizes the receiver should fit in.
 *
 * @return An ASLayout instance defining the layout of the receiver (and its children, if the box layout model is used).
 *
 * @discussion Though this method does not set the bounds of the view, it does have side effects--caching both the
 * constraint and the result.
 *
 * @warning Subclasses must not override this; it caches results from -calculateLayoutThatFits:.  Calling this method may
 * be expensive if result is not cached.
 *
 * @see [ASDisplayNode(Subclassing) calculateLayoutThatFits:]
 */
- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize;


/**
 * @abstract Provides a way to declare a block to provide an ASLayoutSpec without having to subclass ASDisplayNode and
 * implement layoutSpecThatFits:
 *
 * @return A block that takes a constrainedSize ASSizeRange argument, and must return an ASLayoutSpec that includes all
 * of the subnodes to position in the layout. This input-output relationship is identical to the subclass override
 * method -layoutSpecThatFits:
 *
 * @warning Subclasses that implement -layoutSpecThatFits: must not also use .layoutSpecBlock. Doing so will trigger
 * an exception. A future version of the framework may support using both, calling them serially, with the
 * .layoutSpecBlock superseding any values set by the method override.
 */
@property (nonatomic, readwrite, copy, nullable) ASLayoutSpecBlock layoutSpecBlock;

/** 
 * @abstract Return the calculated size.
 *
 * @discussion Ideal for use by subclasses in -layout, having already prompted their subnodes to calculate their size by
 * calling -measure: on them in -calculateLayoutThatFits.
 *
 * @return Size already calculated by -calculateLayoutThatFits:.
 *
 * @warning Subclasses must not override this; it returns the last cached measurement and is never expensive.
 */
@property (nonatomic, readonly, assign) CGSize calculatedSize;

/** 
 * @abstract Return the constrained size range used for calculating layout.
 *
 * @return The minimum and maximum constrained sizes used by calculateLayoutThatFits:.
 */
@property (nonatomic, readonly, assign) ASSizeRange constrainedSizeForCalculatedLayout;

/**
 * @abstract Provides a default intrinsic content size for calculateSizeThatFits:. This is useful when laying out
 * a node that either has no intrinsic content size or should be laid out at a different size than its intrinsic content
 * size. For example, this property could be set on an ASImageNode to display at a size different from the underlying
 * image size.
 *
 * @return The preferred frame size of this node
 */
@property (atomic, assign, readwrite) CGSize preferredFrameSize;

/** @name Managing the nodes hierarchy */


/** 
 * @abstract Add a node as a subnode to this node.
 *
 * @param subnode The node to be added.
 *
 * @discussion The subnode's view will automatically be added to this node's view, lazily if the views are not created 
 * yet.
 */
- (void)addSubnode:(ASDisplayNode *)subnode;

/** 
 * @abstract Insert a subnode before a given subnode in the list.
 *
 * @param subnode The node to insert below another node.
 * @param below The sibling node that will be above the inserted node.
 *
 * @discussion If the views are loaded, the subnode's view will be inserted below the given node's view in the hierarchy 
 * even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below;

/** 
 * @abstract Insert a subnode after a given subnode in the list.
 *
 * @param subnode The node to insert below another node.
 * @param above The sibling node that will be behind the inserted node.
 *
 * @discussion If the views are loaded, the subnode's view will be inserted above the given node's view in the hierarchy
 * even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above;

/** 
 * @abstract Insert a subnode at a given index in subnodes.
 *
 * @param subnode The node to insert.
 * @param idx The index in the array of the subnodes property at which to insert the node. Subnodes indices start at 0
 * and cannot be greater than the number of subnodes.
 *
 * @discussion If this node's view is loaded, ASDisplayNode insert the subnode's view after the subnode at index - 1's 
 * view even if there are other non-displaynode views.
 */
- (void)insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx;

/** 
 * @abstract Replace subnode with replacementSubnode.
 *
 * @param subnode A subnode of self.
 * @param replacementSubnode A node with which to replace subnode.
 *
 * @discussion Should both subnode and replacementSubnode already be subnodes of self, subnode is removed and 
 * replacementSubnode inserted in its place.
 * If subnode is not a subnode of self, this method will throw an exception.
 * If replacementSubnode is nil, this method will throw an exception
 */
- (void)replaceSubnode:(ASDisplayNode *)subnode withSubnode:(ASDisplayNode *)replacementSubnode;

/** 
 * @abstract Remove this node from its supernode.
 *
 * @discussion The node's view will be automatically removed from the supernode's view.
 */
- (void)removeFromSupernode;

/** 
 * @abstract The receiver's immediate subnodes.
 */
@property (nonatomic, readonly, copy) NSArray<ASDisplayNode *> *subnodes;

/** 
 * @abstract The receiver's supernode.
 */
@property (nonatomic, readonly, weak) ASDisplayNode *supernode;


/** @name Drawing and Updating the View */


/** 
 * @abstract Whether this node's view performs asynchronous rendering.
 *
 * @return Defaults to YES, except for synchronous views (ie, those created with -initWithViewBlock: /
 * -initWithLayerBlock:), which are always NO.
 *
 * @discussion If this flag is set, then the node will participate in the current asyncdisplaykit_async_transaction and 
 * do its rendering on the displayQueue instead of the main thread.
 *
 * Asynchronous rendering proceeds as follows:
 *
 * When the view is initially added to the hierarchy, it has -needsDisplay true.
 * After layout, Core Animation will call -display on the _ASDisplayLayer
 * -display enqueues a rendering operation on the displayQueue
 * When the render block executes, it calls the delegate display method (-drawRect:... or -display)
 * The delegate provides contents via this method and an operation is added to the asyncdisplaykit_async_transaction
 * Once all rendering is complete for the current asyncdisplaykit_async_transaction,
 * the completion for the block sets the contents on all of the layers in the same frame
 *
 * If asynchronous rendering is disabled:
 *
 * When the view is initially added to the hierarchy, it has -needsDisplay true.
 * After layout, Core Animation will call -display on the _ASDisplayLayer
 * -display calls  delegate display method (-drawRect:... or -display) immediately
 * -display sets the layer contents immediately with the result
 *
 * Note: this has nothing to do with -[CALayer drawsAsynchronously].
 */
@property (nonatomic, assign) BOOL displaysAsynchronously;

/** 
 * @abstract Whether to draw all descendant nodes' layers/views into this node's layer/view's backing store.
 *
 * @discussion
 * When set to YES, causes all descendant nodes' layers/views to be drawn directly into this node's layer/view's backing 
 * store.  Defaults to NO.
 *
 * If a node's descendants are static (never animated or never change attributes after creation) then that node is a 
 * good candidate for rasterization.  Rasterizing descendants has two main benefits:
 * 1) Backing stores for descendant layers are not created.  Instead the layers are drawn directly into the rasterized
 * container.  This can save a great deal of memory.
 * 2) Since the entire subtree is drawn into one backing store, compositing and blending are eliminated in that subtree
 * which can help improve animation/scrolling/etc performance.
 *
 * Rasterization does not currently support descendants with transform, sublayerTransform, or alpha. Those properties 
 * will be ignored when rasterizing descendants.
 *
 * Note: this has nothing to do with -[CALayer shouldRasterize], which doesn't work with ASDisplayNode's asynchronous 
 * rendering model.
 */
@property (nonatomic, assign) BOOL shouldRasterizeDescendants;

/** 
 * @abstract Prevent the node's layer from displaying.
 *
 * @discussion A subclass may check this flag during -display or -drawInContext: to cancel a display that is already in 
 * progress.
 *
 * Defaults to NO. Does not control display for any child or descendant nodes; for that, use 
 * -recursivelySetDisplaySuspended:.
 *
 * If a setNeedsDisplay occurs while displaySuspended is YES, and displaySuspended is set to NO, then the 
 * layer will be automatically displayed.
 */
@property (nonatomic, assign) BOOL displaySuspended;

/**
 * @abstract Whether size changes should be animated. Default to YES.
 */
@property (nonatomic, assign) BOOL shouldAnimateSizeChanges;

/** 
 * @abstract Prevent the node and its descendants' layer from displaying.
 *
 * @param flag YES if display should be prevented or cancelled; NO otherwise.
 *
 * @see displaySuspended
 */
- (void)recursivelySetDisplaySuspended:(BOOL)flag;

/**
 * @abstract Calls -clearContents on the receiver and its subnode hierarchy.
 *
 * @discussion Clears backing stores and other memory-intensive intermediates.
 * If the node is removed from a visible hierarchy and then re-added, it will automatically trigger a new asynchronous display,
 * as long as displaySuspended is not set.
 * If the node remains in the hierarchy throughout, -setNeedsDisplay is required to trigger a new asynchronous display.
 *
 * @see displaySuspended and setNeedsDisplay
 */
- (void)recursivelyClearContents;

/**
 * @abstract Calls -clearFetchedData on the receiver and its subnode hierarchy.
 *
 * @discussion Clears any memory-intensive fetched content.
 * This method is used to notify the node that it should purge any content that is both expensive to fetch and to
 * retain in memory.
 *
 * @see [ASDisplayNode(Subclassing) clearFetchedData] and [ASDisplayNode(Subclassing) fetchData]
 */
- (void)recursivelyClearFetchedData;

/**
 * @abstract Calls -fetchData on the receiver and its subnode hierarchy.
 *
 * @discussion Fetches content from remote sources for the current node and all subnodes.
 *
 * @see [ASDisplayNode(Subclassing) fetchData] and [ASDisplayNode(Subclassing) clearFetchedData]
 */
- (void)recursivelyFetchData;

/**
 * @abstract Triggers a recursive call to fetchData when the node has an interfaceState of ASInterfaceStateFetchData
 */
- (void)setNeedsDataFetch;

/**
 * @abstract Toggle displaying a placeholder over the node that covers content until the node and all subnodes are
 * displayed.
 *
 * @discussion Defaults to NO.
 */
@property (nonatomic, assign) BOOL placeholderEnabled;

/**
 * @abstract Set the time it takes to fade out the placeholder when a node's contents are finished displaying.
 *
 * @discussion Defaults to 0 seconds.
 */
@property (nonatomic, assign) NSTimeInterval placeholderFadeDuration;

/**
 * @abstract Determines drawing priority of the node. Nodes with higher priority will be drawn earlier.
 *
 * @discussion Defaults to ASDefaultDrawingPriority. There may be multiple drawing threads, and some of them may
 * decide to perform operations in queued order (regardless of drawingPriority)
 */
@property (nonatomic, assign) NSInteger drawingPriority;

/** @name Hit Testing */


/** 
 * @abstract Bounds insets for hit testing.
 *
 * @discussion When set to a non-zero inset, increases the bounds for hit testing to make it easier to tap or perform 
 * gestures on this node.  Default is UIEdgeInsetsZero.
 *
 * This affects the default implementation of -hitTest and -pointInside, so subclasses should call super if you override 
 * it and want hitTestSlop applied.
 */
@property (nonatomic, assign) UIEdgeInsets hitTestSlop;

/** 
 * @abstract Returns a Boolean value indicating whether the receiver contains the specified point.
 *
 * @discussion Includes the "slop" factor specified with hitTestSlop.
 *
 * @param point A point that is in the receiver's local coordinate system (bounds).
 * @param event The event that warranted a call to this method.
 *
 * @return YES if point is inside the receiver's bounds; otherwise, NO.
 */
- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event;


/** @name Converting Between View Coordinate Systems */


/** 
 * @abstract Converts a point from the receiver's coordinate system to that of the specified node.
 *
 * @param point A point specified in the local coordinate system (bounds) of the receiver.
 * @param node The node into whose coordinate system point is to be converted.
 *
 * @return The point converted to the coordinate system of node.
 */
- (CGPoint)convertPoint:(CGPoint)point toNode:(nullable ASDisplayNode *)node;


/** 
 * @abstract Converts a point from the coordinate system of a given node to that of the receiver.
 *
 * @param point A point specified in the local coordinate system (bounds) of node.
 * @param node The node with point in its coordinate system.
 *
 * @return The point converted to the local coordinate system (bounds) of the receiver.
 */
- (CGPoint)convertPoint:(CGPoint)point fromNode:(nullable ASDisplayNode *)node;


/** 
 * @abstract Converts a rectangle from the receiver's coordinate system to that of another view.
 *
 * @param rect A rectangle specified in the local coordinate system (bounds) of the receiver.
 * @param node The node that is the target of the conversion operation.
 *
 * @return The converted rectangle.
 */
- (CGRect)convertRect:(CGRect)rect toNode:(nullable ASDisplayNode *)node;

/** 
 * @abstract Converts a rectangle from the coordinate system of another node to that of the receiver.
 *
 * @param rect A rectangle specified in the local coordinate system (bounds) of node.
 * @param node The node with rect in its coordinate system.
 *
 * @return The converted rectangle.
 */
- (CGRect)convertRect:(CGRect)rect fromNode:(nullable ASDisplayNode *)node;

@end

/**
 * Convenience methods for debugging.
 */

@interface ASDisplayNode (Debugging) <ASLayoutableAsciiArtProtocol>

/**
 * @abstract Return a description of the node hierarchy.
 *
 * @discussion For debugging: (lldb) po [node displayNodeRecursiveDescription]
 */
- (NSString *)displayNodeRecursiveDescription;

@end

NS_ASSUME_NONNULL_END
/**
 * ## UIView bridge
 *
 * ASDisplayNode provides thread-safe access to most of UIView and CALayer properties and methods, traditionally unsafe.
 *
 * Using them will not cause the actual view/layer to be created, and will be applied when it is created (when the view 
 * or layer property is accessed).
 *
 * - NOTE: After the view or layer is created, the properties pass through to the view or layer directly and must be called on the main thread.
 *
 * See UIView and CALayer for documentation on these common properties.
 */
@interface ASDisplayNode (UIViewBridge)

/**
 * Marks the view as needing display. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 */
- (void)setNeedsDisplay;

/**
 * Marks the node as needing layout. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 * 
 * If this node was measured, calling this method triggers an internal relayout: the calculated layout is invalidated,
 * and the supernode is notified or (if this node is the root one) a full measurement pass is executed using the old constrained size.
 *
 * Note: ASCellNode has special behavior in that calling this method will automatically notify 
 * the containing ASTableView / ASCollectionView that the cell should be resized, if necessary.
 */
- (void)setNeedsLayout;

@property (atomic, strong, nullable) id contents;                           // default=nil
@property (atomic, assign)           BOOL clipsToBounds;                    // default==NO
@property (atomic, getter=isOpaque)  BOOL opaque;                           // default==YES

@property (atomic, assign)           BOOL allowsEdgeAntialiasing;
@property (atomic, assign)           unsigned int edgeAntialiasingMask;     // default==all values from CAEdgeAntialiasingMask

@property (atomic, getter=isHidden)  BOOL hidden;                           // default==NO
@property (atomic, assign)           BOOL needsDisplayOnBoundsChange;       // default==NO
@property (atomic, assign)           BOOL autoresizesSubviews;              // default==YES (undefined for layer-backed nodes)
@property (atomic, assign)           UIViewAutoresizing autoresizingMask;   // default==UIViewAutoresizingNone  (undefined for layer-backed nodes)
@property (atomic, assign)           CGFloat alpha;                         // default=1.0f
@property (atomic, assign)           CGRect bounds;                         // default=CGRectZero
@property (atomic, assign)           CGRect frame;                          // default=CGRectZero
@property (atomic, assign)           CGPoint anchorPoint;                   // default={0.5, 0.5}
@property (atomic, assign)           CGFloat zPosition;                     // default=0.0
@property (atomic, assign)           CGPoint position;                      // default=CGPointZero
@property (atomic, assign)           CGFloat cornerRadius;                  // default=0.0
@property (atomic, assign)           CGFloat contentsScale;                 // default=1.0f. See @contentsScaleForDisplay for more info
@property (atomic, assign)           CATransform3D transform;               // default=CATransform3DIdentity
@property (atomic, assign)           CATransform3D subnodeTransform;        // default=CATransform3DIdentity

/**
 * @abstract The node view's background color.
 *
 * @discussion In contrast to UIView, setting a transparent color will not set opaque = NO.
 * This only affects nodes that implement +drawRect like ASTextNode.
*/
@property (atomic, strong, nullable) UIColor *backgroundColor;              // default=nil

@property (atomic, strong, null_resettable)    UIColor *tintColor;          // default=Blue
- (void)tintColorDidChange;     // Notifies the node when the tintColor has changed.

/**
 * @abstract A flag used to determine how a node lays out its content when its bounds change.
 *
 * @discussion This is like UIView's contentMode property, but better. We do our own mapping to layer.contentsGravity in 
 * _ASDisplayView. You can set needsDisplayOnBoundsChange independently. 
 * Thus, UIViewContentModeRedraw is not allowed; use needsDisplayOnBoundsChange = YES instead, and pick an appropriate 
 * contentMode for your content while it's being re-rendered.
 */
@property (atomic, assign)           UIViewContentMode contentMode;         // default=UIViewContentModeScaleToFill

@property (atomic, assign, getter=isUserInteractionEnabled) BOOL userInteractionEnabled; // default=YES (NO for layer-backed nodes)
#if TARGET_OS_IOS
@property (atomic, assign, getter=isExclusiveTouch) BOOL exclusiveTouch;    // default=NO
#endif
@property (atomic, assign, nullable) CGColorRef shadowColor;                // default=opaque rgb black
@property (atomic, assign)           CGFloat shadowOpacity;                 // default=0.0
@property (atomic, assign)           CGSize shadowOffset;                   // default=(0, -3)
@property (atomic, assign)           CGFloat shadowRadius;                  // default=3
@property (atomic, assign)           CGFloat borderWidth;                   // default=0
@property (atomic, assign, nullable) CGColorRef borderColor;                // default=opaque rgb black

// UIResponder methods
// By default these fall through to the underlying view, but can be overridden.
- (BOOL)canBecomeFirstResponder;                                            // default==NO
- (BOOL)becomeFirstResponder;                                               // default==NO (no-op)
- (BOOL)canResignFirstResponder;                                            // default==YES
- (BOOL)resignFirstResponder;                                               // default==NO (no-op)
- (BOOL)isFirstResponder;
- (BOOL)canPerformAction:(nonnull SEL)action withSender:(nonnull id)sender;

#if TARGET_OS_TV
//Focus Engine
- (void)setNeedsFocusUpdate;
- (BOOL)canBecomeFocused;
- (void)updateFocusIfNeeded;
- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator;
- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context;
- (nullable UIView *)preferredFocusedView;
#endif

@end

@interface ASDisplayNode (UIViewBridgeAccessibility)

// Accessibility support
@property (nonatomic, assign)           BOOL isAccessibilityElement;
@property (nonatomic, copy, nullable)   NSString *accessibilityLabel;
@property (nonatomic, copy, nullable)   NSString *accessibilityHint;
@property (nonatomic, copy, nullable)   NSString *accessibilityValue;
@property (nonatomic, assign)           UIAccessibilityTraits accessibilityTraits;
@property (nonatomic, assign)           CGRect accessibilityFrame;
@property (nonatomic, copy, nullable)   UIBezierPath *accessibilityPath;
@property (nonatomic, assign)           CGPoint accessibilityActivationPoint;
@property (nonatomic, copy, nullable)   NSString *accessibilityLanguage;
@property (nonatomic, assign)           BOOL accessibilityElementsHidden;
@property (nonatomic, assign)           BOOL accessibilityViewIsModal;
@property (nonatomic, assign)           BOOL shouldGroupAccessibilityChildren;
@property (nonatomic, assign)           UIAccessibilityNavigationStyle accessibilityNavigationStyle;
#if TARGET_OS_TV
@property(nonatomic, copy, nullable) 	NSArray *accessibilityHeaderElements;
#endif

// Accessibility identification support
@property (nonatomic, copy, nullable)   NSString *accessibilityIdentifier;

@end

/*
 ASDisplayNode participates in ASAsyncTransactions, so you can determine when your subnodes are done rendering.
 See: -(void)asyncdisplaykit_asyncTransactionContainerStateDidChange in ASDisplayNodeSubclass.h
 */
@interface ASDisplayNode (ASDisplayNodeAsyncTransactionContainer) <ASDisplayNodeAsyncTransactionContainer>
@end

/** UIVIew(AsyncDisplayKit) defines convenience method for adding sub-ASDisplayNode to an UIView. */
@interface UIView (AsyncDisplayKit)
/**
 * Convenience method, equivalent to [view addSubview:node.view] or [view.layer addSublayer:node.layer] if layer-backed.
 *
 * @param node The node to be added.
 */
- (void)addSubnode:(nonnull ASDisplayNode *)node;
@end

/** CALayer(AsyncDisplayKit) defines convenience method for adding sub-ASDisplayNode to a CALayer. */
@interface CALayer (AsyncDisplayKit)
/**
 * Convenience method, equivalent to [layer addSublayer:node.layer].
 *
 * @param node The node to be added.
 */
- (void)addSubnode:(nonnull ASDisplayNode *)node;
@end


@interface ASDisplayNode (Deprecated)

- (void)reclaimMemory ASDISPLAYNODE_DEPRECATED;
- (void)recursivelyReclaimMemory ASDISPLAYNODE_DEPRECATED;
@property (nonatomic, assign) BOOL placeholderFadesOut ASDISPLAYNODE_DEPRECATED;

@end
