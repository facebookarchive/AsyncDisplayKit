/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ASDisplayNode.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNodeInternal.h"
#import "ASLayoutOptionsPrivate.h"

#import <objc/runtime.h>

#import "_ASAsyncTransaction.h"
#import "_ASAsyncTransactionContainer+Private.h"
#import "_ASPendingState.h"
#import "_ASDisplayView.h"
#import "_ASScopeTimer.h"
#import "ASDisplayNodeExtras.h"
#import "ASEqualityHelpers.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASLayoutSpec.h"

@interface ASDisplayNode () <UIGestureRecognizerDelegate>

/**
 *
 * See ASDisplayNodeInternal.h for ivars
 *
 */

- (void)_staticInitialize;

@end

// Conditionally time these scopes to our debug ivars (only exist in debug/profile builds)
#if TIME_DISPLAYNODE_OPS
#define TIME_SCOPED(outVar) ASDN::ScopeTimer t(outVar)
#else
#define TIME_SCOPED(outVar)
#endif

@implementation ASDisplayNode

// these dynamic properties all defined in ASLayoutOptionsPrivate.m
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis, alignSelf, ascender, descender, sizeRange, layoutPosition, layoutOptions;
@synthesize name = _name;
@synthesize preferredFrameSize = _preferredFrameSize;
@synthesize isFinalLayoutable = _isFinalLayoutable;

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector)
{
    return ASSubclassOverridesSelector([ASDisplayNode class], subclass, selector);
}

void ASDisplayNodeRespectThreadAffinityOfNode(ASDisplayNode *node, void (^block)())
{
  ASDisplayNodeCAssertNotNil(block, @"block is required");
  if (!block) {
    return;
  }

  {
    // Hold the lock to avoid a race where the node gets loaded while the block is in-flight.
    ASDN::MutexLocker l(node->_propertyLock);
    if (node.nodeLoaded) {
      ASPerformBlockOnMainThread(^{
        block();
      });
    } else {
      block();
    }
  }
}

/**
 *  Returns ASDisplayNodeFlags for the givern class/instance. instance MAY BE NIL.
 *
 *  @param c        the class, required
 *  @param instance the instance, which may be nil. (If so, the class is inspected instead)
 *  @remarks        The instance value is used only if we suspect the class may be dynamic (because it overloads 
 *                  +respondsToSelector: or -respondsToSelector.) In that case we use our "slow path", calling this 
 *                  method on each -init and passing the instance value. While this may seem like an unlikely scenario,
 *                  it turns our our own internal tests use a dynamic class, so it's worth capturing this edge case.
 *
 *  @return ASDisplayNode flags.
 */
static struct ASDisplayNodeFlags GetASDisplayNodeFlags(Class c, ASDisplayNode *instance)
{
  ASDisplayNodeCAssertNotNil(c, @"class is required");

  struct ASDisplayNodeFlags flags = {0};

  flags.isInHierarchy = NO;
  flags.displaysAsynchronously = YES;
  flags.implementsDrawRect = ([c respondsToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] ? 1 : 0);
  flags.implementsImageDisplay = ([c respondsToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  if (instance) {
    flags.implementsDrawParameters = ([instance respondsToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
  } else {
    flags.implementsDrawParameters = ([c instancesRespondToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
  }
  return flags;
}

/**
 *  Returns ASDisplayNodeMethodOverrides for the given class
 *
 *  @param c the class, requireed.
 *
 *  @return ASDisplayNodeMethodOverrides.
 */
static ASDisplayNodeMethodOverrides GetASDisplayNodeMethodOverrides(Class c)
{
  ASDisplayNodeCAssertNotNil(c, @"class is required");
  
  ASDisplayNodeMethodOverrides overrides = ASDisplayNodeMethodOverrideNone;
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesBegan:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesBegan;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesMoved:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesMoved;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesCancelled:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesCancelled;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(touchesEnded:withEvent:))) {
    overrides |= ASDisplayNodeMethodOverrideTouchesEnded;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(layoutSpecThatFits:))) {
    overrides |= ASDisplayNodeMethodOverrideLayoutSpecThatFits;
  }


  return overrides;
}

+ (void)initialize
{
  if (self != [ASDisplayNode class]) {
    
    // Subclasses should never override these
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measure:)), @"Subclass %@ must not override measure method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearContents)), @"Subclass %@ must not override recursivelyClearContents method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearFetchedData)), @"Subclass %@ must not override recursivelyClearFetchedData method", NSStringFromClass(self));

    // At most one of the three layout methods is overridden
    ASDisplayNodeAssert((ASDisplayNodeSubclassOverridesSelector(self, @selector(calculateSizeThatFits:)) ? 1 : 0)
                        + (ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutSpecThatFits:)) ? 1 : 0)
                        + (ASDisplayNodeSubclassOverridesSelector(self, @selector(calculateLayoutThatFits:)) ? 1 : 0) <= 1,
                        @"Subclass %@ must override at most one of the three layout methods: calculateLayoutThatFits, layoutSpecThatFits or calculateSizeThatFits", NSStringFromClass(self));
  }

  // Below we are pre-calculating values per-class and dynamically adding a method (_staticInitialize) to populate these values
  // when each instance is constructed. These values don't change for each class, so there is significant performance benefit
  // in doing it here. +initialize is guaranteed to be called before any instance method so it is safe to add this method here.
  // Note that we take care to detect if the class overrides +respondsToSelector: or -respondsToSelector and take the slow path
  // (recalculating for each instance) to make sure we are always correct.

  BOOL classOverridesRespondsToSelector = ASSubclassOverridesClassSelector([NSObject class], self, @selector(respondsToSelector:));
  BOOL instancesOverrideRespondsToSelector = ASSubclassOverridesSelector([NSObject class], self, @selector(respondsToSelector:));
  struct ASDisplayNodeFlags flags = GetASDisplayNodeFlags(self, nil);
  ASDisplayNodeMethodOverrides methodOverrides = GetASDisplayNodeMethodOverrides(self);

  IMP staticInitialize = imp_implementationWithBlock(^(ASDisplayNode *node) {
    node->_flags = (classOverridesRespondsToSelector || instancesOverrideRespondsToSelector) ? GetASDisplayNodeFlags(node.class, node) : flags;
    node->_methodOverrides = (classOverridesRespondsToSelector) ? GetASDisplayNodeMethodOverrides(node.class) : methodOverrides;
  });

  class_replaceMethod(self, @selector(_staticInitialize), staticInitialize, "v:@");
}

+ (BOOL)layerBackedNodesEnabled
{
  return YES;
}

+ (Class)viewClass
{
  return [_ASDisplayView class];
}

+ (Class)layerClass
{
  return [_ASDisplayLayer class];
}

#pragma mark - Lifecycle

- (void)_staticInitialize
{
  ASDisplayNodeAssert(NO, @"_staticInitialize must be overridden");
}

- (void)_initializeInstance
{
  [self _staticInitialize];
  _contentsScaleForDisplay = ASScreenScale();
  _displaySentinel = [[ASSentinel alloc] init];
  _preferredFrameSize = CGSizeZero;
}

- (id)init
{
  if (!(self = [super init]))
    return nil;

  [self _initializeInstance];

  return self;
}

- (id)initWithViewClass:(Class)viewClass
{
  if (!(self = [super init]))
    return nil;

  ASDisplayNodeAssert([viewClass isSubclassOfClass:[UIView class]], @"should initialize with a subclass of UIView");

  [self _initializeInstance];
  _viewClass = viewClass;
  _flags.synchronous = ![viewClass isSubclassOfClass:[_ASDisplayView class]];

  return self;
}

- (id)initWithLayerClass:(Class)layerClass
{
  if (!(self = [super init]))
    return nil;

  ASDisplayNodeAssert([layerClass isSubclassOfClass:[CALayer class]], @"should initialize with a subclass of CALayer");

  [self _initializeInstance];
  _layerClass = layerClass;
  _flags.synchronous = ![layerClass isSubclassOfClass:[_ASDisplayLayer class]];
  _flags.layerBacked = YES;

  return self;
}

- (id)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  return [self initWithViewBlock:viewBlock didLoadBlock:nil];
}

- (id)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  if (!(self = [super init]))
    return nil;
  
  ASDisplayNodeAssertNotNil(viewBlock, @"should initialize with a valid block that returns a UIView");
  
  [self _initializeInstance];
  _viewBlock = viewBlock;
  _nodeLoadedBlock = didLoadBlock;
  _flags.synchronous = YES;
  
  return self;
}


- (id)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  return [self initWithLayerBlock:layerBlock didLoadBlock:nil];
}

- (id)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  if (!(self = [super init]))
    return nil;
  
  ASDisplayNodeAssertNotNil(layerBlock, @"should initialize with a valid block that returns a CALayer");
  
  [self _initializeInstance];
  _layerBlock = layerBlock;
  _nodeLoadedBlock = didLoadBlock;
  _flags.synchronous = YES;
  _flags.layerBacked = YES;
  
  return self;
}


- (void)dealloc
{
  ASDisplayNodeAssertMainThread();

  self.asyncLayer.asyncDelegate = nil;
  _view.asyncdisplaykit_node = nil;
  _layer.asyncdisplaykit_node = nil;

  // Remove any subnodes so they lose their connection to the now deallocated parent.  This can happen
  // because subnodes do not retain their supernode, but subnodes can legitimately remain alive if another
  // thing outside the view hierarchy system (e.g. async display, controller code, etc). keeps a retained
  // reference to subnodes.

  for (ASDisplayNode *subnode in _subnodes)
    [subnode __setSupernode:nil];

  _view = nil;
  _subnodes = nil;
  if (_flags.layerBacked)
    _layer.delegate = nil;
  _layer = nil;

  [self __setSupernode:nil];
  _pendingViewState = nil;
  _replaceAsyncSentinel = nil;

  _displaySentinel = nil;

  _pendingDisplayNodes = nil;
}

#pragma mark - Core

- (void)__tearDown:(BOOL)tearDown subnodesOfNode:(ASDisplayNode *)node
{
  for (ASDisplayNode *subnode in node.subnodes) {
    if (tearDown) {
      [subnode __unloadNode];
    } else {
      [subnode __loadNode];
    }
  }
}

- (void)__unloadNode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  
  if (_flags.layerBacked)
    _pendingViewState = [_ASPendingState pendingViewStateFromLayer:_layer];
  else
    _pendingViewState = [_ASPendingState pendingViewStateFromView:_view];
    
  [_view removeFromSuperview];
  _view = nil;
  if (_flags.layerBacked)
    _layer.delegate = nil;
  [_layer removeFromSuperlayer];
  _layer = nil;
}

- (void)__loadNode
{
  [self layer];
}

- (ASDisplayNode *)__rasterizedContainerNode
{
  ASDisplayNode *node = self.supernode;
  while (node) {
    if (node.shouldRasterizeDescendants) {
      return node;
    }
    node = node.supernode;
  }
  
  return nil;
}

- (BOOL)__shouldLoadViewOrLayer
{
  return ![self __rasterizedContainerNode];
}

- (BOOL)__shouldSize
{
  return YES;
}

- (void)__exitedHierarchy
{

}

- (UIView *)_viewToLoad
{
  UIView *view;
  ASDN::MutexLocker l(_propertyLock);

  if (_viewBlock) {
    view = _viewBlock();
    ASDisplayNodeAssertNotNil(view, @"View block returned nil");
    ASDisplayNodeAssert(![view isKindOfClass:[_ASDisplayView class]], @"View block should return a synchronously displayed view");
    _viewBlock = nil;
    _viewClass = [view class];
  } else {
    if (!_viewClass) {
      _viewClass = [self.class viewClass];
    }
    view = [[_viewClass alloc] init];
  }

  return view;
}

- (CALayer *)_layerToLoad
{
  CALayer *layer;
  ASDN::MutexLocker l(_propertyLock);

  if (_layerBlock) {
    layer = _layerBlock();
    ASDisplayNodeAssertNotNil(layer, @"Layer block returned nil");
    ASDisplayNodeAssert(![layer isKindOfClass:[_ASDisplayLayer class]], @"Layer block should return a synchronously displayed layer");
    _layerBlock = nil;
    _layerClass = [layer class];
  } else {
    if (!_layerClass) {
      _layerClass = [self.class layerClass];
    }
    layer = [[_layerClass alloc] init];
  }

  return layer;
}

- (void)_loadViewOrLayerIsLayerBacked:(BOOL)isLayerBacked
{
  ASDN::MutexLocker l(_propertyLock);

  if (self._isDeallocating) {
    return;
  }

  if (![self __shouldLoadViewOrLayer]) {
    return;
  }

  if (isLayerBacked) {
    TIME_SCOPED(_debugTimeToCreateView);
    _layer = [self _layerToLoad];
    _layer.delegate = self;
  } else {
    TIME_SCOPED(_debugTimeToCreateView);
    _view = [self _viewToLoad];
    _view.asyncdisplaykit_node = self;
    _layer = _view.layer;
  }
  _layer.asyncdisplaykit_node = self;

  self.asyncLayer.asyncDelegate = self;

  {
    TIME_SCOPED(_debugTimeToApplyPendingState);
    [self _applyPendingStateToViewOrLayer];
  }
  {
    TIME_SCOPED(_debugTimeToAddSubnodeViews);
    [self _addSubnodeViewsAndLayers];
  }
  {
    TIME_SCOPED(_debugTimeForDidLoad);
    [self __didLoad];
  }

  if (self.placeholderEnabled) {
    [self _setupPlaceholderLayer];
  }
}

- (UIView *)view
{
  ASDisplayNodeAssert(!_flags.layerBacked, @"Call to -view undefined on layer-backed nodes");
  if (_flags.layerBacked) {
    return nil;
  }
  if (!_view) {
    ASDisplayNodeAssertMainThread();
    [self _loadViewOrLayerIsLayerBacked:NO];
  }
  return _view;
}

- (CALayer *)layer
{
  if (!_layer) {
    ASDisplayNodeAssertMainThread();

    if (!_flags.layerBacked) {
      return self.view.layer;
    }
    [self _loadViewOrLayerIsLayerBacked:YES];
  }
  return _layer;
}

// Returns nil if our view is not an _ASDisplayView, but will create it if necessary.
- (_ASDisplayView *)ensureAsyncView
{
  return _flags.synchronous ? nil : (_ASDisplayView *)self.view;
}

// Returns nil if the layer is not an _ASDisplayLayer; will not create the layer if nil.
- (_ASDisplayLayer *)asyncLayer
{
  ASDN::MutexLocker l(_propertyLock);
  return [_layer isKindOfClass:[_ASDisplayLayer class]] ? (_ASDisplayLayer *)_layer : nil;
}

- (BOOL)isNodeLoaded
{
  ASDN::MutexLocker l(_propertyLock);
  return (_view != nil || (_flags.layerBacked && _layer != nil));
}

- (NSString *)name
{
  ASDN::MutexLocker l(_propertyLock);
  return _name;
}

- (void)setName:(NSString *)name
{
  ASDN::MutexLocker l(_propertyLock);
  if (!ASObjectIsEqual(_name, name)) {
    _name = [name copy];
  }
}

- (BOOL)isSynchronous
{
  return _flags.synchronous;
}

- (void)setSynchronous:(BOOL)flag
{
  _flags.synchronous = flag;
}

- (void)setLayerBacked:(BOOL)isLayerBacked
{
  if (![self.class layerBackedNodesEnabled]) return;

  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(!_view && !_layer, @"Cannot change isLayerBacked after layer or view has loaded");
  ASDisplayNodeAssert(!_viewBlock && !_layerBlock, @"Cannot change isLayerBacked when a layer or view block is provided");
  ASDisplayNodeAssert(!_viewClass && !_layerClass, @"Cannot change isLayerBacked when a layer or view class is provided");

  if (isLayerBacked != _flags.layerBacked && !_view && !_layer) {
    _flags.layerBacked = isLayerBacked;
  }
}

- (BOOL)isLayerBacked
{
  ASDN::MutexLocker l(_propertyLock);
  return _flags.layerBacked;
}

#pragma mark -

- (CGSize)measure:(CGSize)constrainedSize
{
  return [self measureWithSizeRange:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASDN::MutexLocker l(_propertyLock);
  return [self __measureWithSizeRange:constrainedSize];
}

- (ASLayout *)__measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);

  if (![self __shouldSize])
    return nil;

  // only calculate the size if
  //  - we haven't already
  //  - the constrained size range is different
  if (!_flags.isMeasured || !ASSizeRangeEqualToSizeRange(constrainedSize, _constrainedSize)) {
    _layout = [self calculateLayoutThatFits:constrainedSize];
    _constrainedSize = constrainedSize;
    _flags.isMeasured = YES;
  }

  ASDisplayNodeAssertTrue(_layout.layoutableObject == self);
  ASDisplayNodeAssertTrue(_layout.size.width >= 0.0);
  ASDisplayNodeAssertTrue(_layout.size.height >= 0.0);

  // we generate placeholders at measureWithSizeRange: time so that a node is guaranteed to have a placeholder ready to go
  // also if a node has no size, it should not have a placeholder
  if (self.placeholderEnabled && [self _displaysAsynchronously] && _layout.size.width > 0.0 && _layout.size.height > 0.0) {
    if (!_placeholderImage) {
      _placeholderImage = [self placeholderImage];
    }

    if (_placeholderLayer) {
      _placeholderLayer.contents = (id)_placeholderImage.CGImage;
    }
  }

  return _layout;
}

- (BOOL)displaysAsynchronously
{
  ASDN::MutexLocker l(_propertyLock);
  return [self _displaysAsynchronously];
}

/**
 * Core implementation of -displaysAsynchronously.
 * Must be called with _propertyLock held.
 */
- (BOOL)_displaysAsynchronously
{
  ASDisplayNodeAssertThreadAffinity(self);
  if (self.isSynchronous) {
    return NO;
  } else {
    return _flags.displaysAsynchronously;
  }
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.synchronous)
    return;

  ASDN::MutexLocker l(_propertyLock);

  if (_flags.displaysAsynchronously == displaysAsynchronously)
    return;

  _flags.displaysAsynchronously = displaysAsynchronously;

  self.asyncLayer.displaysAsynchronously = displaysAsynchronously;
}

- (BOOL)shouldRasterizeDescendants
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _flags.shouldRasterizeDescendants;
}

- (void)setShouldRasterizeDescendants:(BOOL)flag
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  
  if (_flags.shouldRasterizeDescendants == flag)
    return;
  
  _flags.shouldRasterizeDescendants = flag;
  
  if (self.isNodeLoaded) {
    //recursively tear down or build up subnodes
    [self recursivelyClearContents];
    [self __tearDown:flag subnodesOfNode:self];
    if (flag == NO) {
      [self _addSubnodeViewsAndLayers];
    }
    
    [self recursivelyDisplayImmediately];
  }
}

- (CGFloat)contentsScaleForDisplay
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  return _contentsScaleForDisplay;
}

- (void)setContentsScaleForDisplay:(CGFloat)contentsScaleForDisplay
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  if (_contentsScaleForDisplay == contentsScaleForDisplay)
    return;

  _contentsScaleForDisplay = contentsScaleForDisplay;
}

- (void)displayImmediately
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.synchronous, @"this method is designed for asynchronous mode only");

  [[self asyncLayer] displayImmediately];
}

- (void)recursivelyDisplayImmediately
{
  ASDN::MutexLocker l(_propertyLock);
  for (ASDisplayNode *child in _subnodes) {
    [child recursivelyDisplayImmediately];
  }
  [self displayImmediately];
}

- (void)__setNeedsLayout
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  
  if (!_flags.isMeasured) {
    return;
  }
  
  ASSizeRange oldConstrainedSize = _constrainedSize;
  [self invalidateCalculatedLayout];
  
  if (_supernode) {
    // Cause supernode's layout to be invalidated
    [_supernode setNeedsLayout];
  } else {
    // This is the root node. Trigger a full measurement pass on *current* thread. Old constrained size is re-used.
    [self measureWithSizeRange:oldConstrainedSize];

    CGRect oldBounds = self.bounds;
    CGSize oldSize = oldBounds.size;
    CGSize newSize = _layout.size;
    
    if (! CGSizeEqualToSize(oldSize, newSize)) {
      self.bounds = (CGRect){ oldBounds.origin, newSize };
      
      // Frame's origin must be preserved. Since it is computed from bounds size, anchorPoint
      // and position (see frame setter in ASDisplayNode+UIViewBridge), position needs to be adjusted.
      CGPoint anchorPoint = self.anchorPoint;
      CGPoint oldPosition = self.position;
      CGFloat xDelta = (newSize.width - oldSize.width) * anchorPoint.x;
      CGFloat yDelta = (newSize.height - oldSize.height) * anchorPoint.y;
      self.position = CGPointMake(oldPosition.x + xDelta, oldPosition.y + yDelta);
    }
  }
}

- (void)__setSafeFrame:(CGRect)rect
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  
  BOOL useLayer = (_layer && ASDisplayNodeThreadIsMain());
  
  CGPoint origin      = (useLayer ? _layer.bounds.origin : self.bounds.origin);
  CGPoint anchorPoint = (useLayer ? _layer.anchorPoint   : self.anchorPoint);
  
  CGRect bounds       = (CGRect){ origin, rect.size };
  CGPoint position    = CGPointMake(rect.origin.x + rect.size.width * anchorPoint.x,
                                    rect.origin.y + rect.size.height * anchorPoint.y);
  
  if (useLayer) {
    _layer.bounds = bounds;
    _layer.position = position;
  } else {
    self.bounds = bounds;
    self.position = position;
  }
}

// These private methods ensure that subclasses are not required to call super in order for _renderingSubnodes to be properly managed.

- (void)__layout
{
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_propertyLock);
  if (CGRectEqualToRect(self.bounds, CGRectZero)) {
    return;     // Performing layout on a zero-bounds view often results in frame calculations with negative sizes after applying margins, which will cause measureWithSizeRange: on subnodes to assert.
  }
  _placeholderLayer.frame = self.bounds;
  [self layout];
  [self layoutDidFinish];
}

- (void)layoutDidFinish
{
}

- (CATransform3D)_transformToAncestor:(ASDisplayNode *)ancestor
{
  CATransform3D transform = CATransform3DIdentity;
  ASDisplayNode *currentNode = self;
  while (currentNode.supernode) {
    if (currentNode == ancestor) {
      return transform;
    }

    CGPoint anchorPoint = currentNode.anchorPoint;
    CGRect bounds = currentNode.bounds;
    CGPoint position = currentNode.position;
    CGPoint origin = CGPointMake(position.x - bounds.size.width * anchorPoint.x,
                                 position.y - bounds.size.height * anchorPoint.y);

    transform = CATransform3DTranslate(transform, origin.x, origin.y, 0);
    transform = CATransform3DTranslate(transform, -bounds.origin.x, -bounds.origin.y, 0);
    currentNode = currentNode.supernode;
  }
  return transform;
}

static inline BOOL _ASDisplayNodeIsAncestorOfDisplayNode(ASDisplayNode *possibleAncestor, ASDisplayNode *possibleDescendent)
{
  ASDisplayNode *supernode = possibleDescendent;
  while (supernode) {
    if (supernode == possibleAncestor) {
      return YES;
    }
    supernode = supernode.supernode;
  }

  return NO;
}

/**
 * NOTE: It is an error to try to convert between nodes which do not share a common ancestor. This behavior is
 * disallowed in UIKit documentation and the behavior is left undefined. The output does not have a rigorously defined
 * failure mode (i.e. returning CGPointZero or returning the point exactly as passed in). Rather than track the internal
 * undefined and undocumented behavior of UIKit in ASDisplayNode, this operation is defined to be incorrect in all
 * circumstances and must be fixed wherever encountered.
 */
static inline ASDisplayNode *_ASDisplayNodeFindClosestCommonAncestor(ASDisplayNode *node1, ASDisplayNode *node2)
{
  ASDisplayNode *possibleAncestor = node1;
  while (possibleAncestor) {
    if (_ASDisplayNodeIsAncestorOfDisplayNode(possibleAncestor, node2)) {
      break;
    }
    possibleAncestor = possibleAncestor.supernode;
  }

  ASDisplayNodeCAssertNotNil(possibleAncestor, @"Could not find a common ancestor between node1: %@ and node2: %@", node1, node2);
  return possibleAncestor;
}

static inline ASDisplayNode *_getRootNode(ASDisplayNode *node)
{
  // node <- supernode on each loop
  // previous <- node on each loop where node is not nil
  // previous is the final non-nil value of supernode, i.e. the root node
  ASDisplayNode *previousNode = node;
  while ((node = [node supernode])) {
    previousNode = node;
  }
  return previousNode;
}

static inline CATransform3D _calculateTransformFromReferenceToTarget(ASDisplayNode *referenceNode, ASDisplayNode *targetNode)
{
  ASDisplayNode *ancestor = _ASDisplayNodeFindClosestCommonAncestor(referenceNode, targetNode);

  // Transform into global (away from reference coordinate space)
  CATransform3D transformToGlobal = [referenceNode _transformToAncestor:ancestor];

  // Transform into local (via inverse transform from target to ancestor)
  CATransform3D transformToLocal = CATransform3DInvert([targetNode _transformToAncestor:ancestor]);

  return CATransform3DConcat(transformToGlobal, transformToLocal);
}

- (CGPoint)convertPoint:(CGPoint)point fromNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? node : _getRootNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(node, self);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to point
  return CGPointApplyAffineTransform(point, flattenedTransform);
}

- (CGPoint)convertPoint:(CGPoint)point toNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? node : _getRootNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to point
  return CGPointApplyAffineTransform(point, flattenedTransform);
}

- (CGRect)convertRect:(CGRect)rect fromNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? node : _getRootNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(node, self);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to rect
  return CGRectApplyAffineTransform(rect, flattenedTransform);
}

- (CGRect)convertRect:(CGRect)rect toNode:(ASDisplayNode *)node
{
  ASDisplayNodeAssertThreadAffinity(self);
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? node : _getRootNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to rect
  return CGRectApplyAffineTransform(rect, flattenedTransform);
}

#pragma mark - _ASDisplayLayerDelegate

- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer
{
  // Subclass hook.
  [self displayWillStart];
}

- (void)didDisplayAsyncLayer:(_ASDisplayLayer *)layer
{
  // Subclass hook.
  [self displayDidFinish];
}

#pragma mark - CALayerDelegate

// We are only the delegate for the layer when we are layer-backed, as UIView performs this funcition normally
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
  if (event == kCAOnOrderIn) {
    [self __enterHierarchy];
  } else if (event == kCAOnOrderOut) {
    [self __exitHierarchy];
  }

  ASDisplayNodeAssert(_flags.layerBacked, @"We shouldn't get called back here if there is no layer");
  return (id<CAAction>)[NSNull null];
}

#pragma mark -

static bool disableNotificationsForMovingBetweenParents(ASDisplayNode *from, ASDisplayNode *to)
{
  if (!from || !to) return NO;
  if (from->_flags.synchronous) return NO;
  if (to->_flags.synchronous) return NO;
  if (from->_flags.isInHierarchy != to->_flags.isInHierarchy) return NO;
  return YES;
}

- (void)addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  ASDisplayNode *oldParent = subnode.supernode;
  if (!subnode || subnode == self || oldParent == self)
    return;

  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  BOOL isMovingEquivalentParents = disableNotificationsForMovingBetweenParents(oldParent, self);
  if (isMovingEquivalentParents) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  [subnode removeFromSupernode];

  if (!_subnodes)
    _subnodes = [[NSMutableArray alloc] init];

  [_subnodes addObject:subnode];

  if (self.nodeLoaded) {
    // If this node has a view or layer, force the subnode to also create its view or layer and add it to the hierarchy here.
    // Otherwise there is no way for the subnode's view or layer to enter the hierarchy, except recursing down all
    // subnodes on the main thread after the node tree has been created but before the first display (which
    // could introduce performance problems).
    if (ASDisplayNodeThreadIsMain()) {
      [self _addSubnodeSubviewOrSublayer:subnode];
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self _addSubnodeSubviewOrSublayer:subnode];
      });
    }
  }

  ASDisplayNodeAssert(isMovingEquivalentParents == disableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (isMovingEquivalentParents) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }

  [subnode __setSupernode:self];
}

/*
 Private helper function.
 You must hold _propertyLock to call this.

 @param subnode       The subnode to insert
 @param subnodeIndex  The index in _subnodes to insert it
 @param viewSublayerIndex The index in layer.sublayers (not view.subviews) at which to insert the view (use if we can use the view API) otherwise pass NSNotFound
 @param sublayerIndex The index in layer.sublayers at which to insert the layer (use if either parent or subnode is layer-backed) otherwise pass NSNotFound
 @param oldSubnode Remove this subnode before inserting; ok to be nil if no removal is desired
 */
- (void)_insertSubnode:(ASDisplayNode *)subnode atSubnodeIndex:(NSInteger)subnodeIndex sublayerIndex:(NSInteger)sublayerIndex andRemoveSubnode:(ASDisplayNode *)oldSubnode
{
  if (subnodeIndex == NSNotFound)
    return;

  ASDisplayNode *oldParent = [subnode _deallocSafeSupernode];
  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  BOOL isMovingEquivalentParents = disableNotificationsForMovingBetweenParents(oldParent, self);
  if (isMovingEquivalentParents) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  [subnode removeFromSupernode];

  if (!_subnodes)
    _subnodes = [[NSMutableArray alloc] init];

  [oldSubnode removeFromSupernode];
  [_subnodes insertObject:subnode atIndex:subnodeIndex];

  // Don't bother inserting the view/layer if in a rasterized subtree, becuase there are no layers in the hierarchy and none of this could possibly work.
  if (!_flags.shouldRasterizeDescendants && ![self __rasterizedContainerNode]) {
    if (_layer) {
      ASDisplayNodeCAssertMainThread();

      ASDisplayNodeAssert(sublayerIndex != NSNotFound, @"Should pass either a valid sublayerIndex");

      if (sublayerIndex != NSNotFound) {
        BOOL canUseViewAPI = !subnode.isLayerBacked && !self.isLayerBacked;
        // If we can use view API, do. Due to an apple bug, -insertSubview:atIndex: actually wants a LAYER index, which we pass in
        if (canUseViewAPI && sublayerIndex != NSNotFound) {
          [_view insertSubview:subnode.view atIndex:sublayerIndex];
        } else if (sublayerIndex != NSNotFound) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wconversion"
          [_layer insertSublayer:subnode.layer atIndex:sublayerIndex];
#pragma clang diagnostic pop
        }
      }
    }
  }

  ASDisplayNodeAssert(isMovingEquivalentParents == disableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (isMovingEquivalentParents) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }

  [subnode __setSupernode:self];
}

- (void)replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  if (!replacementSubnode || [oldSubnode _deallocSafeSupernode] != self) {
    ASDisplayNodeAssert(0, @"Bad use of api. Invalid subnode to replace async.");
    return;
  }

  ASDisplayNodeAssert(!(self.nodeLoaded && !oldSubnode.nodeLoaded), @"ASDisplayNode corruption bug. We have view loaded, but child node does not.");
  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger subnodeIndex = [_subnodes indexOfObjectIdenticalTo:oldSubnode];
  NSInteger sublayerIndex = NSNotFound;

  if (_layer) {
    sublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:oldSubnode.layer];
    ASDisplayNodeAssert(sublayerIndex != NSNotFound, @"Somehow oldSubnode's supernode is self, yet we could not find it in our layers to replace");
    if (sublayerIndex == NSNotFound) return;
  }

  [self _insertSubnode:replacementSubnode atSubnodeIndex:subnodeIndex sublayerIndex:sublayerIndex andRemoveSubnode:oldSubnode];
}

// This is just a convenience to avoid a bunch of conditionals
static NSInteger incrementIfFound(NSInteger i) {
  return i == NSNotFound ? NSNotFound : i + 1;
}

- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  if (!subnode)
    return;

  ASDisplayNodeAssert([below _deallocSafeSupernode] == self, @"Node to insert below must be a subnode");
  if ([below _deallocSafeSupernode] != self)
    return;

  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger belowSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:below];
  NSInteger belowSublayerIndex = NSNotFound;

  if (_layer) {
    belowSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:below.layer];
    ASDisplayNodeAssert(belowSublayerIndex != NSNotFound, @"Somehow below's supernode is self, yet we could not find it in our layers to reference");
    if (belowSublayerIndex == NSNotFound)
      return;
  }
  // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to insert it will mess up our calculation
  if ([subnode _deallocSafeSupernode] == self) {
    NSInteger currentIndexInSubnodes = [_subnodes indexOfObjectIdenticalTo:subnode];
    if (currentIndexInSubnodes < belowSubnodeIndex) {
      belowSubnodeIndex--;
    }
    if (_layer) {
      NSInteger currentIndexInSublayers = [_layer.sublayers indexOfObjectIdenticalTo:subnode.layer];
      if (currentIndexInSublayers < belowSublayerIndex) {
        belowSublayerIndex--;
      }
    }
  }

  ASDisplayNodeAssert(belowSubnodeIndex != NSNotFound, @"Couldn't find below in subnodes");

  [self _insertSubnode:subnode atSubnodeIndex:belowSubnodeIndex sublayerIndex:belowSublayerIndex andRemoveSubnode:nil];
}

- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  if (!subnode)
    return;

  ASDisplayNodeAssert([above _deallocSafeSupernode] == self, @"Node to insert above must be a subnode");
  if ([above _deallocSafeSupernode] != self)
    return;

  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger aboveSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:above];
  NSInteger aboveSublayerIndex = NSNotFound;

  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, becuase there are no layers in the hierarchy and none of this could possibly work.
  if (!_flags.shouldRasterizeDescendants && ![self __rasterizedContainerNode]) {
    if (_layer) {
      aboveSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:above.layer];
      ASDisplayNodeAssert(aboveSublayerIndex != NSNotFound, @"Somehow above's supernode is self, yet we could not find it in our layers to replace");
      if (aboveSublayerIndex == NSNotFound)
        return;
    }
    ASDisplayNodeAssert(aboveSubnodeIndex != NSNotFound, @"Couldn't find above in subnodes");

    // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to insert it will mess up our calculation
    if ([subnode _deallocSafeSupernode] == self) {
      NSInteger currentIndexInSubnodes = [_subnodes indexOfObjectIdenticalTo:subnode];
      if (currentIndexInSubnodes <= aboveSubnodeIndex) {
        aboveSubnodeIndex--;
      }
      if (_layer) {
        NSInteger currentIndexInSublayers = [_layer.sublayers indexOfObjectIdenticalTo:subnode.layer];
        if (currentIndexInSublayers <= aboveSublayerIndex) {
          aboveSublayerIndex--;
        }
      }
    }
  }

  [self _insertSubnode:subnode atSubnodeIndex:incrementIfFound(aboveSubnodeIndex) sublayerIndex:incrementIfFound(aboveSublayerIndex) andRemoveSubnode:nil];
}

- (void)insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  if (idx > _subnodes.count || idx < 0) {
    NSString *reason = [NSString stringWithFormat:@"Cannot insert a subnode at index %zd. Count is %zd", idx, _subnodes.count];
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:reason userInfo:nil];
  }

  NSInteger sublayerIndex = NSNotFound;

  // Account for potentially having other subviews
  if (_layer && idx == 0) {
    sublayerIndex = 0;
  } else if (_layer) {
    ASDisplayNode *positionInRelationTo = (_subnodes.count > 0 && idx > 0) ? _subnodes[idx - 1] : nil;
    if (positionInRelationTo) {
      sublayerIndex = incrementIfFound([_layer.sublayers indexOfObjectIdenticalTo:positionInRelationTo.layer]);
    }
  }

  [self _insertSubnode:subnode atSubnodeIndex:idx sublayerIndex:sublayerIndex andRemoveSubnode:nil];
}


- (void)_addSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"_addSubnodeSubview: should never be called before our own view is created");

  BOOL canUseViewAPI = !self.isLayerBacked && !subnode.isLayerBacked;
  if (canUseViewAPI) {
    [_view addSubview:subnode.view];
  } else {
    // Disallow subviews in a layer-backed node
    ASDisplayNodeAssert(subnode.isLayerBacked, @"Cannot add a subview to a layer-backed node; only sublayers permitted.");
    [_layer addSublayer:subnode.layer];
  }
}

- (void)_addSubnodeViewsAndLayers
{
  ASDisplayNodeAssertMainThread();

  for (ASDisplayNode *node in [_subnodes copy]) {
    [self _addSubnodeSubviewOrSublayer:node];
  }
}

- (void)_removeSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  // Don't call self.supernode here because that will retain/autorelease the supernode.  This method -_removeSupernode: is often called while tearing down a node hierarchy, and the supernode in question might be in the middle of its -dealloc.  The supernode is never messaged, only compared by value, so this is safe.
  // The particular issue that triggers this edge case is when a node calls -removeFromSupernode on a subnode from within its own -dealloc method.
  if (!subnode || [subnode _deallocSafeSupernode] != self)
    return;

  [_subnodes removeObjectIdenticalTo:subnode];

  [subnode __setSupernode:nil];
}

- (void)removeFromSupernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  if (!_supernode)
    return;

  // Do this before removing the view from the hierarchy, as the node will clear its supernode pointer when its view is removed from the hierarchy.
  [_supernode _removeSubnode:self];

  if (ASDisplayNodeThreadIsMain()) {
    if (_flags.layerBacked) {
      [_layer removeFromSuperlayer];
    } else {
      [_view removeFromSuperview];
    }
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (_flags.layerBacked) {
        [_layer removeFromSuperlayer];
      } else {
        [_view removeFromSuperview];
      }
    });
  }
}

- (BOOL)__visibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  return _flags.visibilityNotificationsDisabled > 0;
}

- (void)__incrementVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  const size_t maxVisibilityIncrement = (1ULL<<VISIBILITY_NOTIFICATIONS_DISABLED_BITS) - 1ULL;
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled < maxVisibilityIncrement, @"Oops, too many increments of the visibility notifications API");
  if (_flags.visibilityNotificationsDisabled < maxVisibilityIncrement)
    _flags.visibilityNotificationsDisabled++;
}

- (void)__decrementVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled > 0, @"Can't decrement past 0");
  if (_flags.visibilityNotificationsDisabled > 0)
    _flags.visibilityNotificationsDisabled--;
}

// This uses the layer hieararchy for safety. Who knows what people might do and it would be bad to have visibilty out of sync
- (BOOL)__hasParentWithVisibilityNotificationsDisabled
{
  CALayer *layer = _layer;
  do {
    ASDisplayNode *node = ASLayerToDisplayNode(layer);
    if (node) {
      if (node->_flags.visibilityNotificationsDisabled) {
        return YES;
      }
    }
    layer = layer.superlayer;
  } while (layer);

  return NO;
}

- (void)__enterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"Should not cause recursive __enterHierarchy");
  if (!self.inHierarchy && !_flags.visibilityNotificationsDisabled && ![self __hasParentWithVisibilityNotificationsDisabled]) {
    self.inHierarchy = YES;
    _flags.isEnteringHierarchy = YES;
    if (self.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveWillEnterHierarchy];
    } else {
      [self willEnterHierarchy];
    }
    _flags.isEnteringHierarchy = NO;

    CALayer *layer = self.layer;
    if (!self.layer.contents) {
      [layer setNeedsDisplay];
    }
  }
}

- (void)__exitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"Should not cause recursive __exitHierarchy");
  if (self.inHierarchy && !_flags.visibilityNotificationsDisabled && ![self __hasParentWithVisibilityNotificationsDisabled]) {
    self.inHierarchy = NO;

    [self.asyncLayer cancelAsyncDisplay];

    _flags.isExitingHierarchy = YES;
    if (self.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveDidExitHierarchy];
    } else {
      [self didExitHierarchy];
    }
    _flags.isExitingHierarchy = NO;
  }
}

- (void)_recursiveWillEnterHierarchy
{
  if (_flags.visibilityNotificationsDisabled) {
    return;
  }

  _flags.isEnteringHierarchy = YES;
  [self willEnterHierarchy];
  _flags.isEnteringHierarchy = NO;

  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursiveWillEnterHierarchy];
  }
}

- (void)_recursiveDidExitHierarchy
{
  if (_flags.visibilityNotificationsDisabled) {
    return;
  }

  _flags.isExitingHierarchy = YES;
  [self didExitHierarchy];
  _flags.isExitingHierarchy = NO;

  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursiveDidExitHierarchy];
  }
}

- (NSArray *)subnodes
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return [_subnodes copy];
}

- (ASDisplayNode *)supernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _supernode;
}

// This is a thread-method to return the supernode without causing it to be retained autoreleased.  See -_removeSubnode: for details.
- (ASDisplayNode *)_deallocSafeSupernode
{
  ASDN::MutexLocker l(_propertyLock);
  return _supernode;
}

- (void)__setSupernode:(ASDisplayNode *)supernode
{
  ASDN::MutexLocker l(_propertyLock);
  _supernode = supernode;
}

// Track that a node will be displayed as part of the current node hierarchy.
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeWillDisplay:(ASDisplayNode *)node
{
  ASDN::MutexLocker l(_propertyLock);

  if (!_pendingDisplayNodes) {
    _pendingDisplayNodes = [[NSMutableSet alloc] init];
  }

  [_pendingDisplayNodes addObject:node];
}

// Notify that a node that was pending display finished
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeDidDisplay:(ASDisplayNode *)node
{
  ASDN::MutexLocker l(_propertyLock);

  [_pendingDisplayNodes removeObject:node];

  // only trampoline if there is a placeholder and nodes are done displaying
  if ([self _pendingDisplayNodesHaveFinished] && _placeholderLayer.superlayer) {
    dispatch_async(dispatch_get_main_queue(), ^{
      void (^cleanupBlock)() = ^{
        [self _tearDownPlaceholderLayer];
      };

      if (_placeholderFadeDuration > 0.0) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:cleanupBlock];
        [CATransaction setAnimationDuration:_placeholderFadeDuration];
        _placeholderLayer.opacity = 0.0;
        [CATransaction commit];
      } else {
        cleanupBlock();
      }
    });
  }
}

// Helper method to check that all nodes that the current node is waiting to display are finished
// Use this method to check to remove any placeholder layers
- (BOOL)_pendingDisplayNodesHaveFinished
{
  return _pendingDisplayNodes.count == 0;
}

// Helper method to summarize whether or not the node run through the display process
- (BOOL)_implementsDisplay
{
  return _flags.implementsDrawRect == YES || _flags.implementsImageDisplay == YES;
}

- (void)_setupPlaceholderLayer
{
  ASDisplayNodeAssertMainThread();

  _placeholderLayer = [CALayer layer];
  // do not set to CGFLOAT_MAX in the case that something needs to be overtop the placeholder
  _placeholderLayer.zPosition = 9999.0;
}

- (void)_tearDownPlaceholderLayer
{
  ASDisplayNodeAssertMainThread();

  [_placeholderLayer removeFromSuperlayer];
}

void recursivelyEnsureDisplayForLayer(CALayer *layer)
{
  // This recursion must handle layers in various states:
  // 1. Just added to hierarchy, CA hasn't yet called -display
  // 2. Previously in a hierarchy (such as a working window owned by an Intelligent Preloading class, like ASTableView / ASCollectionView / ASViewController)
  // 3. Has no content to display at all
  // Specifically for case 1), we need to explicitly trigger a -display call now.
  // Otherwise, there is no opportunity to block the main thread after CoreAnimation's transaction commit
  // (even a runloop observer at a late call order will not stop the next frame from compositing, showing placeholders).
  
  ASDisplayNode *node = [layer asyncdisplaykit_node];
  if (!layer.contents && [node _implementsDisplay]) {
    // For layers that do get displayed here, this immediately kicks off the work on the concurrent -[_ASDisplayLayer displayQueue].
    // At the same time, it creates an associated _ASAsyncTransaction, which we can use to block on display completion.  See ASDisplayNode+AsyncDisplay.mm.
    [layer displayIfNeeded];
  }
  
  // Kick off the recursion first, so that all necessary display calls are sent and the displayQueue is full of parallelizable work.
  for (CALayer *sublayer in layer.sublayers) {
    recursivelyEnsureDisplayForLayer(sublayer);
  }
  
  // As the recursion unwinds, verify each transaction is complete and block if it is not.
  // While blocking on one transaction, others may be completing concurrently, so it doesn't matter which blocks first.
  BOOL waitUntilComplete = (!node.shouldBypassEnsureDisplay);
  if (waitUntilComplete) {
    for (_ASAsyncTransaction *transaction in [layer.asyncdisplaykit_asyncLayerTransactions copy]) {
      // Even if none of the layers have had a chance to start display earlier, they will still be allowed to saturate a multicore CPU while blocking main.
      // This significantly reduces time on the main thread relative to UIKit.
      [transaction waitUntilComplete];
    }
  }
}

- (void)recursivelyEnsureDisplay
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.isNodeLoaded, @"Node must have layer or view loaded to use -recursivelyEnsureDisplay");
  ASDisplayNodeAssert(self.inHierarchy && (self.isLayerBacked || self.view.window != nil), @"Node must be in a hierarchy to use -recursivelyEnsureDisplay");
  
  CALayer *layer = self.layer;
  // -layoutIfNeeded is recursive, and even walks up to superlayers to check if they need layout,
  // so we should call it outside of starting the recursion below.  If our own layer is not marked
  // as dirty, we can assume layout has run on this subtree before.
  if ([layer needsLayout]) {
    [layer layoutIfNeeded];
  }
  recursivelyEnsureDisplayForLayer(layer);
}

- (void)setShouldBypassEnsureDisplay:(BOOL)shouldBypassEnsureDisplay
{
  ASDN::MutexLocker l(_propertyLock);
  _flags.shouldBypassEnsureDisplay = shouldBypassEnsureDisplay;
}

- (BOOL)shouldBypassEnsureDisplay
{
  ASDN::MutexLocker l(_propertyLock);
  return _flags.shouldBypassEnsureDisplay;
}

#pragma mark - For Subclasses

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  if (_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) {
    ASLayoutSpec *layoutSpec = [self layoutSpecThatFits:constrainedSize];
    layoutSpec.isMutable = NO;
    ASLayout *layout = [layoutSpec measureWithSizeRange:constrainedSize];
    // Make sure layoutableObject of the root layout is `self`, so that the flattened layout will be structurally correct.
    if (layout.layoutableObject != self) {
      layout.position = CGPointZero;
      layout = [ASLayout layoutWithLayoutableObject:self size:layout.size sublayouts:@[layout]];
    }
    return [layout flattenedLayoutUsingPredicateBlock:^BOOL(ASLayout *evaluatedLayout) {
      return [_subnodes containsObject:evaluatedLayout.layoutableObject];
    }];
  } else {
    // If neither -layoutSpecThatFits: nor -calculateSizeThatFits: is overridden by subclassses, preferredFrameSize should be used,
    // assume that the default implementation of -calculateSizeThatFits: returns it.
    CGSize size = [self calculateSizeThatFits:constrainedSize.max];
    return [ASLayout layoutWithLayoutableObject:self size:ASSizeRangeClamp(constrainedSize, size)];
  }
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _preferredFrameSize;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return [ASLayoutSpec new];
}

- (ASLayout *)calculatedLayout
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _layout;
}

- (CGSize)calculatedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _layout.size;
}

- (ASSizeRange)constrainedSizeForCalculatedLayout
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _constrainedSize;
}

- (void)setPreferredFrameSize:(CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(_propertyLock);
  if (! CGSizeEqualToSize(_preferredFrameSize, preferredFrameSize)) {
    _preferredFrameSize = preferredFrameSize;
    [self invalidateCalculatedLayout];
  }
}

- (CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(_propertyLock);
  return _preferredFrameSize;
}

- (UIImage *)placeholderImage
{
  return nil;
}

- (void)invalidateCalculatedLayout
{
  ASDisplayNodeAssertThreadAffinity(self);
  // This will cause -measureWithSizeRange: to actually compute the size instead of returning the previously cached size
  _flags.isMeasured = NO;
}

- (void)__didLoad
{
  if (_nodeLoadedBlock) {
    _nodeLoadedBlock(self);
    _nodeLoadedBlock = nil;
  }
  [self didLoad];
}

- (void)didLoad
{
  ASDisplayNodeAssertMainThread();
}

- (void)willEnterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isEnteringHierarchy, @"You should never call -willEnterHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
}

- (void)didExitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isExitingHierarchy, @"You should never call -didExitHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");

  [self __exitedHierarchy];
}

- (void)clearContents
{
  self.layer.contents = nil;
  _placeholderLayer.contents = nil;
  _placeholderImage = nil;
}

- (void)recursivelyClearContents
{
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode recursivelyClearContents];
  }
  [self clearContents];
}

- (void)fetchData
{
  // subclass override
}

- (void)recursivelyFetchData
{
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode recursivelyFetchData];
  }
  [self fetchData];
}

- (void)clearFetchedData
{
  // subclass override
}

- (void)recursivelyClearFetchedData
{
  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode recursivelyClearFetchedData];
  }
  [self clearFetchedData];
}

- (void)layout
{
  ASDisplayNodeAssertMainThread();

  if (!_flags.isMeasured) {
    return;
  }

  // Assume that _layout was flattened and is 1-level deep.
  for (ASLayout *subnodeLayout in _layout.sublayouts) {
    ASDisplayNodeAssert([_subnodes containsObject:subnodeLayout.layoutableObject], @"Cached sublayouts must only contain subnodes' layout.");
    [((ASDisplayNode *)subnodeLayout.layoutableObject) __setSafeFrame:CGRectMake(subnodeLayout.position.x,
                                                                                 subnodeLayout.position.y,
                                                                                 subnodeLayout.size.width,
                                                                                 subnodeLayout.size.height)];
  }
}

- (void)displayWillStart
{
  // in case current node takes longer to display than it's subnodes, treat it as a dependent node
  [self _pendingNodeWillDisplay:self];

  [_supernode subnodeDisplayWillStart:self];

  if (_placeholderImage && _placeholderLayer && self.layer.contents == nil) {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _placeholderLayer.contents = (id)_placeholderImage.CGImage;
    _placeholderLayer.opacity = 1.0;
    [CATransaction commit];
    [self.layer addSublayer:_placeholderLayer];
  }
}

- (void)displayDidFinish
{
  [self _pendingNodeDidDisplay:self];

  [_supernode subnodeDisplayDidFinish:self];
}

- (void)subnodeDisplayWillStart:(ASDisplayNode *)subnode
{
  [self _pendingNodeWillDisplay:subnode];
}

- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode
{
  [self _pendingNodeDidDisplay:subnode];
}

- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale
{
  if (contentsScale != self.contentsScaleForDisplay) {
    self.contentsScaleForDisplay = contentsScale;
    [self setNeedsDisplay];
  }
}

- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale
{
  [self setNeedsDisplayAtScale:contentsScale];

  ASDN::MutexLocker l(_propertyLock);
  for (ASDisplayNode *child in _subnodes) {
    [child recursivelySetNeedsDisplayAtScale:contentsScale];
  }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // subclass hook
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  // subclass hook
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  // subclass hook
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  // subclass hook
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  // This method is only implemented on UIView on iOS 6+.
  ASDisplayNodeAssertMainThread();

  if (!_view)
    return YES;

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = _view.superview;
  return [superview gestureRecognizerShouldBegin:gestureRecognizer];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  return [_view hitTest:point withEvent:event];
}

- (void)setHitTestSlop:(UIEdgeInsets)hitTestSlop
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  _hitTestSlop = hitTestSlop;
}

- (UIEdgeInsets)hitTestSlop
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _hitTestSlop;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();
  UIEdgeInsets slop = self.hitTestSlop;
  if (_view && UIEdgeInsetsEqualToEdgeInsets(slop, UIEdgeInsetsZero)) {
    // Safer to use UIView's -pointInside:withEvent: if we can.
    return [_view pointInside:point withEvent:event];
  } else {
    return CGRectContainsPoint(UIEdgeInsetsInsetRect(self.bounds, slop), point);
  }
}


#pragma mark - Pending View State
- (_ASPendingState *)pendingViewState
{
  if (!_pendingViewState) {
    _pendingViewState = [[_ASPendingState alloc] init];
    ASDisplayNodeAssertNotNil(_pendingViewState, @"should have created a pendingViewState");
  }

  return _pendingViewState;
}

- (void)_applyPendingStateToViewOrLayer
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"must have a view or layer");

  // If no view/layer properties were set before the view/layer were created, _pendingViewState will be nil and the default values
  // for the view/layer are still valid.
  ASDN::MutexLocker l(_propertyLock);

  if (_flags.layerBacked) {
    [_pendingViewState applyToLayer:_layer];
  } else {
    [_pendingViewState applyToView:_view];
  }

  _pendingViewState = nil;

  // TODO: move this into real pending state
  if (_flags.displaySuspended) {
    self.asyncLayer.displaySuspended = YES;
  }
  if (!_flags.displaysAsynchronously) {
    self.asyncLayer.displaysAsynchronously = NO;
  }
}

// This method has proved helpful in a few rare scenarios, similar to a category extension on UIView, but assumes knowledge of _ASDisplayView.
// It's considered private API for now and its use should not be encouraged.
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass
{
  ASDisplayNode *supernode = self.supernode;
  while (supernode) {
    if ([supernode isKindOfClass:supernodeClass])
      return supernode;
    supernode = supernode.supernode;
  }

  UIView *view = self.view.superview;
  while (view) {
    ASDisplayNode *viewNode = ((_ASDisplayView *)view).asyncdisplaykit_node;
    if (viewNode) {
      if ([viewNode isKindOfClass:supernodeClass])
        return viewNode;
    }

    view = view.superview;
  }

  return nil;
}

- (void)recursivelySetDisplaySuspended:(BOOL)flag
{
  _recursivelySetDisplaySuspended(self, nil, flag);
}

static void _recursivelySetDisplaySuspended(ASDisplayNode *node, CALayer *layer, BOOL flag)
{
  // If there is no layer, but node whose its view is loaded, then we can traverse down its layer hierarchy.  Otherwise we must stick to the node hierarchy to avoid loading views prematurely.  Note that for nodes that haven't loaded their views, they can't possibly have subviews/sublayers, so we don't need to traverse the layer hierarchy for them.
  if (!layer && node && node.nodeLoaded) {
    layer = node.layer;
  }

  // If we don't know the node, but the layer is an async layer, get the node from the layer.
  if (!node && layer && [layer isKindOfClass:[_ASDisplayLayer class]]) {
    node = layer.asyncdisplaykit_node;
  }

  // Set the flag on the node.  If this is a pure layer (no node) then this has no effect (plain layers don't support preventing/cancelling display).
  node.displaySuspended = flag;

  if (layer && !node.shouldRasterizeDescendants) {
    // If there is a layer, recurse down the layer hierarchy to set the flag on descendants.  This will cover both layer-based and node-based children.
    for (CALayer *sublayer in layer.sublayers) {
      _recursivelySetDisplaySuspended(nil, sublayer, flag);
    }
  } else {
    // If there is no layer (view not loaded yet) or this node rasterizes descendants (there won't be a layer tree to traverse), recurse down the subnode hierarchy to set the flag on descendants.  This covers only node-based children, but for a node whose view is not loaded it can't possibly have nodeless children.
    for (ASDisplayNode *subnode in node.subnodes) {
      _recursivelySetDisplaySuspended(subnode, nil, flag);
    }
  }
}

- (BOOL)displaySuspended
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _flags.displaySuspended;
}

- (void)setDisplaySuspended:(BOOL)flag
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.synchronous)
    return;

  ASDN::MutexLocker l(_propertyLock);

  if (_flags.displaySuspended == flag)
    return;

  _flags.displaySuspended = flag;

  self.asyncLayer.displaySuspended = flag;

  if ([self _implementsDisplay]) {
    if (flag) {
      [_supernode subnodeDisplayDidFinish:self];
    } else {
      [_supernode subnodeDisplayWillStart:self];
    }
  }
}

- (BOOL)isInHierarchy
{
  ASDisplayNodeAssertThreadAffinity(self);

  ASDN::MutexLocker l(_propertyLock);
  return _flags.isInHierarchy;
}

- (void)setInHierarchy:(BOOL)inHierarchy
{
  ASDisplayNodeAssertThreadAffinity(self);

  ASDN::MutexLocker l(_propertyLock);
  _flags.isInHierarchy = inHierarchy;
}

+ (dispatch_queue_t)asyncSizingQueue
{
  static dispatch_queue_t asyncSizingQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    asyncSizingQueue = dispatch_queue_create("org.AsyncDisplayKit.ASDisplayNode.asyncSizingQueue", DISPATCH_QUEUE_CONCURRENT);
    // we use the highpri queue to prioritize UI rendering over other async operations
    dispatch_set_target_queue(asyncSizingQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
  });

  return asyncSizingQueue;
}

- (BOOL)_isMarkedForReplacement
{
  ASDN::MutexLocker l(_propertyLock);

  return _replaceAsyncSentinel != nil;
}

- (ASSentinel *)_asyncReplaceSentinel
{
  ASDN::MutexLocker l(_propertyLock);

  if (!_replaceAsyncSentinel) {
    _replaceAsyncSentinel = [[ASSentinel alloc] init];
  }
  return _replaceAsyncSentinel;
}

// Calls completion with nil to indicated cancellation
- (void)_enqueueAsyncSizingWithSentinel:(ASSentinel *)sentinel completion:(void(^)(ASDisplayNode *n))completion;
{
  int32_t sentinelValue = sentinel.value;

  // This is what we're going to use for sizing. Hope you like it :D
  CGRect bounds = self.bounds;

  dispatch_async([[self class] asyncSizingQueue], ^{
    // Check sentinel before, bail early
    if (sentinel.value != sentinelValue)
      return dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });

    [self measure:bounds.size];

    // Check sentinel after, bail early
    if (sentinel.value != sentinelValue)
      return dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });

    // Success; not cancelled
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(self);
    });
  });

}

- (BOOL)canBecomeFirstResponder {
    return NO;
}

- (BOOL)canResignFirstResponder {
    return YES;
}

- (BOOL)isFirstResponder {
    ASDisplayNodeAssertMainThread();
    return _view != nil && [_view isFirstResponder];
}

// Note: this implicitly loads the view if it hasn't been loaded yet.
- (BOOL)becomeFirstResponder {
    ASDisplayNodeAssertMainThread();
    return !self.layerBacked && [self canBecomeFirstResponder] && [self.view becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    ASDisplayNodeAssertMainThread();
    return !self.layerBacked && [self canResignFirstResponder] && [_view resignFirstResponder];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    ASDisplayNodeAssertMainThread();
    return !self.layerBacked && [self.view canPerformAction:action withSender:sender];
}

- (id<ASLayoutable>)finalLayoutable
{
  return self;
}

@end

@implementation ASDisplayNode (Debugging)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
- (NSString *)description
{
  if (self.name) {
    return [NSString stringWithFormat:@"<%@ %p name = %@>", self.class, self, self.name];
  } else {
    return [super description];
  }
}
#pragma clang diagnostic pop

- (NSString *)debugDescription
{
  NSString *notableTargetDesc = (_flags.layerBacked ? @" [layer]" : @" [view]");
  if (_view && _viewClass) { // Nonstandard view is loaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@ : %p]", _view.class, _view];
  } else if (_layer && _layerClass) { // Nonstandard layer is loaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@ : %p]", _layer.class, _layer];
  } else if (_viewClass) { // Nonstandard view class unloaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@]", _viewClass];
  } else if (_layerClass) { // Nonstandard layer class unloaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@]", _layerClass];
  } else if (_viewBlock) { // Nonstandard lazy view unloaded
    notableTargetDesc = @" [block]";
  } else if (_layerBlock) { // Nonstandard lazy layer unloaded
    notableTargetDesc = @" [block]";
  }
  if (self.name) {
    return [NSString stringWithFormat:@"<%@ %p name = %@%@>", self.class, self, self.name, notableTargetDesc];
  } else {
    return [NSString stringWithFormat:@"<%@ %p%@>", self.class, self, notableTargetDesc];
  }
}

- (NSString *)descriptionForRecursiveDescription
{
  NSString *creationTypeString = nil;
#if TIME_DISPLAYNODE_OPS
  creationTypeString = [NSString stringWithFormat:@"cr8:%.2lfms dl:%.2lfms ap:%.2lfms ad:%.2lfms",  1000 * _debugTimeToCreateView, 1000 * _debugTimeForDidLoad, 1000 * _debugTimeToApplyPendingState, 1000 * _debugTimeToAddSubnodeViews];
#endif

  return [NSString stringWithFormat:@"<%@ alpha:%.2f isLayerBacked:%d %@>", self.description, self.alpha, self.isLayerBacked, creationTypeString];
}

- (NSString *)displayNodeRecursiveDescription
{
  return [self _recursiveDescriptionHelperWithIndent:@""];
}

- (NSString *)_recursiveDescriptionHelperWithIndent:(NSString *)indent
{
  NSMutableString *subtree = [[[indent stringByAppendingString: self.descriptionForRecursiveDescription] stringByAppendingString:@"\n"] mutableCopy];
  for (ASDisplayNode *n in self.subnodes) {
    [subtree appendString:[n _recursiveDescriptionHelperWithIndent:[indent stringByAppendingString:@" | "]]];
  }
  return subtree;
}

#pragma mark - ASLayoutableAsciiArtProtocol

- (NSString *)asciiArtString
{
    return [ASLayoutSpec asciiArtStringForChildren:@[] parentName:[self asciiArtName]];
}

- (NSString *)asciiArtName
{
    return NSStringFromClass([self class]);
}

@end

// We use associated objects as a last resort if our view is not a _ASDisplayView ie it doesn't have the _node ivar to write to

static const char *ASDisplayNodeAssociatedNodeKey = "ASAssociatedNode";

@implementation UIView (ASDisplayNodeInternal)
@dynamic asyncdisplaykit_node;

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, node, OBJC_ASSOCIATION_ASSIGN); // Weak reference to avoid cycle, since the node retains the view.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  ASDisplayNode *node = objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
  return node;
}

@end

@implementation CALayer (ASDisplayNodeInternal)
@dynamic asyncdisplaykit_node;
@end


@implementation UIView (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)node
{
  if (node.layerBacked) {
    [self.layer addSublayer:node.layer];
  } else {
    [self addSubview:node.view];
  }
}

- (NSString *)name
{
  return self.asyncdisplaykit_node.name;
}

@end

@implementation CALayer (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)node
{
  [self addSublayer:node.layer];
}

- (NSString *)name
{
  return self.asyncdisplaykit_node.name;
}

@end


@implementation ASDisplayNode (Deprecated)

- (void)setPlaceholderFadesOut:(BOOL)placeholderFadesOut
{
  self.placeholderFadeDuration = placeholderFadesOut ? 0.1 : 0.0;
}

- (BOOL)placeholderFadesOut
{
  return self.placeholderFadeDuration > 0.0;
}

- (void)reclaimMemory
{
  [self clearContents];
}

- (void)recursivelyReclaimMemory
{
  [self recursivelyClearContents];
}

@end
