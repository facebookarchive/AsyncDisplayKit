/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <pthread.h>

#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASThread.h>

//
// The following methods either must or can be overriden by subclasses of ASDisplayNode.
// These methods should never be called directly by other classes.
//

@interface ASDisplayNode (ASDisplayNodeSubclasses)

// the view class to use when creating a new display node instance. Defaults to _ASDisplayView.
+ (Class)viewClass;

// Returns YES if a cache node, defaults to NO
@property (nonatomic, assign, readonly, getter=isCacheNode) BOOL cacheNode;

// Returns array of cached strict descendants (excludes self). if this is not a cacheNode, returns nil
@property (nonatomic, copy, readonly) NSArray *cachedNodes;

// Returns the parent cache node, if any. node caching must be enabled
@property (nonatomic, assign, readonly) ASDisplayNode *superCacheNode;

// Called on the main thread immediately after self.view is created.  Best time to add gesture recognizers to the view.
- (void)didLoad;

// Called on the main thread by the view's -layoutSubviews.  Layout all subnodes or subviews in this method.
- (void)layout;

// Called on the main thread by the view's -layoutSubviews, after -layout.  Gives a chance for subclasses to perform actions after the subclass and superclass have finished laying out.
- (void)layoutDidFinish;

// Subclasses that override should expect this method to be called on a non-main thread.  The returned size is cached by
// ASDisplayNode for quick access during -layout, via -calculatedSize.  Other expensive work that needs to be done
// before display can be performed here, and using ivars to cache any valuable intermediate results is encouraged.  This
// method should not be called directly outside of ASDisplayNode; use -sizeToFit: or -calculatedSize instead.
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize;

// Subclasses should call this method to invalidate the previously measured and cached size for the display node, when the contents of
// the node change in such a way as to require measuring it again.
- (void)invalidateCalculatedSize;

// Subclasses should implement -display if the layer's contents will be set directly to an arbitrary buffer (e.g. decoded JPEG).
// Called on a background thread, some time after the view has been created.  This method is called if -drawInContext: is not implemented.
- (void)display;

// Subclasses should implement if a backing store / context is desired.  Called on a background thread, some time after the view has been created.
- (void)drawInContext:(CGContextRef)ctx;

/**
 @abstract Indicates that the receiver has finished displaying.
 @discussion Subclasses may override this method to be notified when display (asynchronous or synchronous) has completed.
 */
- (void)displayDidFinish;

- (void)asyncdisplaykit_asyncTransactionContainerStateDidChange;

// Subclasses may optionally implement the touch handling methods.
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;

// Override to make this node respond differently to touches: hide touches from subviews, send all touches to certain subviews (hit area maximizing), etc.
// Returns a UIView, not ASDisplayNode, for two reasons:
// 1) allows sending events to plain UIViews that don't have attached nodes, 2) hitTest: is never called before the views are created.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event;

// Subclasses should override this if they don't want their contentsScale changed. This changes an internal property
- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale;

// Recursively calls setNeedsDisplayAtScale: on subnodes. Note that only the node tree is walked, not the view or layer trees.
// Subclasses may override this if they require modifying the scale set on their child nodes.
- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale;

// Use setNeedsDisplayAtScale: and then after display, the display node will set the layer's contentsScale. This is to prevent jumps when re-rasterizing at a different contentsScale.
// Read this property if you need to know the future contentsScale of your layer, eg in drawParameters
@property (nonatomic, assign, readonly) CGFloat contentsScaleForDisplay;

// Whether the view or layer of this display node is currently in a window
@property (nonatomic, readonly, assign, getter=isInWindow) BOOL inWindow;

// The function that gets called for each display node in -recursiveDescription
- (NSString *)descriptionForRecursiveDescription;

@end

@interface ASDisplayNode (ASDisplayNodePrivate)
// This method has proven helpful in a few rare scenarios, similar to a category extension on UIView,
// but it's considered private API for now and its use should not be encouraged.
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass;
@end

#define ASDisplayNodeAssertThreadAffinity(viewNode)   ASDisplayNodeAssert(!viewNode || ASDisplayNodeThreadIsMain() || !(viewNode).isViewLoaded, @"Incorrect display node thread affinity")
#define ASDisplayNodeCAssertThreadAffinity(viewNode) ASDisplayNodeCAssert(!viewNode || ASDisplayNodeThreadIsMain() || !(viewNode).isViewLoaded, @"Incorrect display node thread affinity")
