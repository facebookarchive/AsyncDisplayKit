//
//  ASDisplayNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+Subclasses.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Beta.h"

#import <objc/runtime.h>

#import "_ASAsyncTransaction.h"
#import "_ASAsyncTransactionContainer+Private.h"
#import "_ASPendingState.h"
#import "_ASDisplayView.h"
#import "_ASScopeTimer.h"
#import "_ASCoreAnimationExtras.h"
#import "ASDisplayNodeExtras.h"
#import "ASTraitCollection.h"
#import "ASEqualityHelpers.h"
#import "ASRunLoopQueue.h"
#import "ASEnvironmentInternal.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASLayoutSpec.h"
#import "ASLayoutValidation.h"
#import "ASCellNode.h"

NSInteger const ASDefaultDrawingPriority = ASDefaultTransactionPriority;
NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification = @"ASRenderingEngineDidDisplayScheduledNodes";
NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp = @"ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp";

// Forward declare CALayerDelegate protocol as the iOS 10 SDK moves CALayerDelegate from a formal delegate to a protocol.
// We have to forward declare the protocol as this place otherwise it will not compile compiling with an Base SDK < iOS 10
@protocol CALayerDelegate;

@interface ASDisplayNode () <UIGestureRecognizerDelegate, _ASDisplayLayerDelegate, _ASTransitionContextCompletionDelegate>

/**
 *
 * See ASDisplayNodeInternal.h for ivars
 *
 */

- (void)_staticInitialize;

@end

//#define LOG(...) NSLog(__VA_ARGS__)
#define LOG(...)

// Conditionally time these scopes to our debug ivars (only exist in debug/profile builds)
#if TIME_DISPLAYNODE_OPS
#define TIME_SCOPED(outVar) ASDN::ScopeTimer t(outVar)
#else
#define TIME_SCOPED(outVar)
#endif

@implementation ASDisplayNode

// these dynamic properties all defined in ASLayoutOptionsPrivate.m
@dynamic spacingAfter, spacingBefore, flexGrow, flexShrink, flexBasis,
         alignSelf, ascender, descender, sizeRange, layoutPosition, layoutableType;

@synthesize name = _name;
@synthesize preferredFrameSize = _preferredFrameSize;
@synthesize isFinalLayoutable = _isFinalLayoutable;
@synthesize threadSafeBounds = _threadSafeBounds;

static BOOL usesImplicitHierarchyManagement = NO;

+ (BOOL)usesImplicitHierarchyManagement
{
  return usesImplicitHierarchyManagement;
}

+ (void)setUsesImplicitHierarchyManagement:(BOOL)enabled
{
  usesImplicitHierarchyManagement = enabled;
}

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector)
{
  return ASSubclassOverridesSelector([ASDisplayNode class], subclass, selector);
}

// For classes like ASTableNode, ASCollectionNode, ASScrollNode and similar - we have to be sure to set certain properties
// like setFrame: and setBackgroundColor: directly to the UIView and not apply it to the layer only.
BOOL ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(ASDisplayNodeFlags flags)
{
  return flags.synchronous && !flags.layerBacked;
}

_ASPendingState *ASDisplayNodeGetPendingState(ASDisplayNode *node)
{
  ASDN::MutexLocker l(node->_propertyLock);
  _ASPendingState *result = node->_pendingViewState;
  if (result == nil) {
    result = [[_ASPendingState alloc] init];
    node->_pendingViewState = result;
  }
  return result;
}

/**
 *  Returns ASDisplayNodeFlags for the given class/instance. instance MAY BE NIL.
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
  flags.shouldAnimateSizeChanges = YES;
  flags.implementsDrawRect = ([c respondsToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] ? 1 : 0);
  flags.implementsImageDisplay = ([c respondsToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  if (instance) {
    flags.implementsDrawParameters = ([instance respondsToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
    flags.implementsInstanceDrawRect = ([instance respondsToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] ? 1 : 0);
    flags.implementsInstanceImageDisplay = ([instance respondsToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  } else {
    flags.implementsDrawParameters = ([c instancesRespondToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);
    flags.implementsInstanceDrawRect = ([c instancesRespondToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] ? 1 : 0);
    flags.implementsInstanceImageDisplay = ([c instancesRespondToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  }
  return flags;
}

/**
 *  Returns ASDisplayNodeMethodOverrides for the given class
 *
 *  @param c the class, required.
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

  // At most a layoutSpecBlock or one of the three layout methods is overridden
#define __ASDisplayNodeCheckForLayoutMethodOverrides \
    ASDisplayNodeAssert(_layoutSpecBlock != NULL || \
    (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateSizeThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(layoutSpecThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateLayoutThatFits:)) ? 1 : 0) <= 1, \
    @"Subclass %@ must at least provide a layoutSpecBlock or override at most one of the three layout methods: calculateLayoutThatFits, layoutSpecThatFits or calculateSizeThatFits", NSStringFromClass(self.class))

+ (void)initialize
{
  [super initialize];
  if (self != [ASDisplayNode class]) {
    
    // Subclasses should never override these
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measure:)), @"Subclass %@ must not override measure method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearContents)), @"Subclass %@ must not override recursivelyClearContents method", NSStringFromClass(self));
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearFetchedData)), @"Subclass %@ must not override recursivelyClearFetchedData method", NSStringFromClass(self));
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
  
  __unused Class initializeSelf = self;

  IMP staticInitialize = imp_implementationWithBlock(^(ASDisplayNode *node) {
    ASDisplayNodeAssert(node.class == initializeSelf, @"Node class %@ does not have a matching _staticInitialize method; check to ensure [super initialize] is called within any custom +initialize implementations!  Overridden methods will not be called unless they are also implemented by superclass %@", node.class, initializeSelf);
    node->_flags = (classOverridesRespondsToSelector || instancesOverrideRespondsToSelector) ? GetASDisplayNodeFlags(node.class, node) : flags;
    node->_methodOverrides = (classOverridesRespondsToSelector) ? GetASDisplayNodeMethodOverrides(node.class) : methodOverrides;
  });

  class_replaceMethod(self, @selector(_staticInitialize), staticInitialize, "v:@");
}

+ (void)load
{
  // Ensure this value is cached on the main thread before needed in the background.
  ASScreenScale();
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

+ (void)scheduleNodeForRecursiveDisplay:(ASDisplayNode *)node
{
  static dispatch_once_t onceToken;
  static ASRunLoopQueue<ASDisplayNode *> *renderQueue;
  dispatch_once(&onceToken, ^{
    renderQueue = [[ASRunLoopQueue<ASDisplayNode *> alloc] initWithRunLoop:CFRunLoopGetMain()
                                                                andHandler:^(ASDisplayNode * _Nonnull dequeuedItem, BOOL isQueueDrained) {
      [dequeuedItem _recursivelyTriggerDisplayAndBlock:NO];
      if (isQueueDrained) {
        CFAbsoluteTime timestamp = CFAbsoluteTimeGetCurrent();
        [[NSNotificationCenter defaultCenter] postNotificationName:ASRenderingEngineDidDisplayScheduledNodesNotification
                                                            object:nil
                                                          userInfo:@{ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp: @(timestamp)}];
      }
    }];
  });

  [renderQueue enqueue:node];
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
  
  _environmentState = ASEnvironmentStateMakeDefault();
  
  _flags.canClearContentsOfLayer = YES;
  _flags.canCallNeedsDisplayOfLayer = NO;
}

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  [self _initializeInstance];

  return self;
}

- (instancetype)initWithViewClass:(Class)viewClass
{
  if (!(self = [super init]))
    return nil;

  ASDisplayNodeAssert([viewClass isSubclassOfClass:[UIView class]], @"should initialize with a subclass of UIView");

  [self _initializeInstance];
  _viewClass = viewClass;
  _flags.synchronous = ![viewClass isSubclassOfClass:[_ASDisplayView class]];

  return self;
}

- (instancetype)initWithLayerClass:(Class)layerClass
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

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  return [self initWithViewBlock:viewBlock didLoadBlock:nil];
}

- (instancetype)initWithViewBlock:(ASDisplayNodeViewBlock)viewBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
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

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  return [self initWithLayerBlock:layerBlock didLoadBlock:nil];
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
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
  // Synchronous nodes may not be able to call the hierarchy notifications, so only enforce for regular nodes.
  ASDisplayNodeAssert(_flags.synchronous || !ASInterfaceStateIncludesVisible(_interfaceState), @"Node should always be marked invisible before deallocating; interfaceState: %lu, %@", (unsigned long)_interfaceState, self);
  
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

  _displaySentinel = nil;

  _pendingDisplayNodes = nil;
}

#pragma mark - Core

- (void)__unloadNode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssert([self isNodeLoaded], @"Implementation shouldn't call __unloadNode if not loaded: %@", self);
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

- (BOOL)__shouldLoadViewOrLayer
{
  return !(_hierarchyState & ASHierarchyStateRasterized);
}

- (BOOL)__shouldSize
{
  return YES;
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
  
  // Update flags related to special handling of UIImageView layers. More details on the flags
  if (_flags.synchronous) {
    if ([view isKindOfClass:[UIImageView class]]) {
      _flags.canClearContentsOfLayer = NO;
    } else {
      _flags.canCallNeedsDisplayOfLayer = YES;
    }
  }

  return view;
}

- (CALayer *)_layerToLoad
{
  CALayer *layer;
  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(_flags.layerBacked, @"_layerToLoad is only for layer-backed nodes");

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
    // Surpress warning for Base SDK > 10.0
    _layer.delegate = (id<CALayerDelegate>)self;
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
  if (ASDisplayNodeThreadIsMain()) {
    // Because the view and layer can only be created and destroyed on Main, that is also the only thread
    // where the state of this property can change. As an optimization, we can avoid locking.
    return (_view != nil || (_layer != nil && _flags.layerBacked));
  } else {
    ASDN::MutexLocker l(_propertyLock);
    return (_view != nil || (_layer != nil && _flags.layerBacked));
  }
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

#pragma mark - Layout measurement calculation

- (CGSize)measure:(CGSize)constrainedSize
{
  return [self measureWithSizeRange:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASDN::MutexLocker l(_propertyLock);
  if (! [self shouldMeasureWithSizeRange:constrainedSize]) {
    return _layout;
  }
  
  [self cancelLayoutTransitionsInProgress];

  ASLayout *previousLayout = _layout;
  ASLayout *newLayout = [self calculateLayoutThatFits:constrainedSize];
  
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                          pendingLayout:newLayout
                                                         previousLayout:previousLayout];
  } else {
    ASLayoutTransition *layoutTransition = nil;
    if (self.usesImplicitHierarchyManagement) {
      layoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                    pendingLayout:newLayout
                                                   previousLayout:previousLayout];
    }
    
    [self _applyLayout:newLayout layoutTransition:layoutTransition];
    [self _completeLayoutCalculation];
  }

  return newLayout;
}

- (BOOL)shouldMeasureWithSizeRange:(ASSizeRange)constrainedSize
{
  ASDN::MutexLocker l(_propertyLock);
  if (![self __shouldSize]) {
    return NO;
  }
  
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    ASLayoutableContext context =  ASLayoutableGetCurrentContext();
    if (ASLayoutableContextIsNull(context) || _pendingTransitionID != context.transitionID) {
      return NO;
    }
  }
  
  // Only generate a new layout if:
  // - The current layout is dirty
  // - The passed constrained size is different than the layout's constrained size
  return ([self _hasDirtyLayout] || !ASSizeRangeEqualToSizeRange(constrainedSize, _layout.constrainedSizeRange));
}

- (BOOL)_hasDirtyLayout
{
  return _layout == nil || _layout.isDirty;
}

- (ASLayoutableType)layoutableType
{
  return ASLayoutableTypeDisplayNode;
}

- (BOOL)canLayoutAsynchronous
{
  return !self.isNodeLoaded;
}

#pragma mark - Layout Transition

- (void)transitionLayoutWithAnimation:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  if (_layout == nil) {
    // constrainedSizeRange returns a struct and is invalid to call on nil.
    // Defaulting to CGSizeZero can cause negative values in client layout code.
    return;
  }
  [self invalidateCalculatedLayout];
  [self transitionLayoutWithSizeRange:_layout.constrainedSizeRange
                             animated:animated
                   shouldMeasureAsync:shouldMeasureAsync
                measurementCompletion:completion];
}

- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  ASDisplayNodeAssertMainThread();
  if (! [self shouldMeasureWithSizeRange:constrainedSize]) {
    return;
  }
  
  {
    ASDN::MutexLocker l(_propertyLock);
    ASDisplayNodeAssert(ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO, @"Can't start a transition when one of the supernodes is performing one.");
  }

  int32_t transitionID = [self _startNewTransition];
  
  ASDisplayNodePerformBlockOnEverySubnode(self, ^(ASDisplayNode * _Nonnull node) {
    ASDisplayNodeAssert([node _isTransitionInProgress] == NO, @"Can't start a transition when one of the subnodes is performing one.");
    node.hierarchyState |= ASHierarchyStateLayoutPending;
    node.pendingTransitionID = transitionID;
  });
  
  void (^transitionBlock)() = ^{
    if ([self _shouldAbortTransitionWithID:transitionID]) {
      return;
    }
    
    ASLayout *newLayout;
    {
      ASLayoutableSetCurrentContext(ASLayoutableContextMake(transitionID, NO));

      ASDN::MutexLocker l(_propertyLock);
      BOOL disableImplicitHierarchyManagement = self.usesImplicitHierarchyManagement == NO;
      self.usesImplicitHierarchyManagement = YES; // Temporary flag for 1.9.x
      newLayout = [self calculateLayoutThatFits:constrainedSize];
      if (disableImplicitHierarchyManagement) {
        self.usesImplicitHierarchyManagement = NO; // Temporary flag for 1.9.x
      }
      
      ASLayoutableClearCurrentContext();
    }
    
    if ([self _shouldAbortTransitionWithID:transitionID]) {
      return;
    }
    
    ASPerformBlockOnMainThread(^{
      // Grab _propertyLock here to make sure this transition isn't invalidated
      // right after it passed the validation test and before it proceeds
      ASDN::MutexLocker l(_propertyLock);

      if ([self _shouldAbortTransitionWithID:transitionID]) {
        return;
      }
      
      ASLayout *previousLayout = _layout;
      [self _applyLayout:newLayout layoutTransition:nil];
      
      ASDisplayNodePerformBlockOnEverySubnode(self, ^(ASDisplayNode * _Nonnull node) {
        [node _applyPendingLayoutContext];
        [node _completeLayoutCalculation];
        node.hierarchyState &= (~ASHierarchyStateLayoutPending);
      });
        
      [self _finishOrCancelTransition];
      
      if (completion) {
        completion();
      }
      
      _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                            pendingLayout:newLayout
                                                          previousLayout:previousLayout];
      [_pendingLayoutTransition applySubnodeInsertions];

      _transitionContext = [[_ASTransitionContext alloc] initWithAnimation:animated
                                                            layoutDelegate:_pendingLayoutTransition
                                                        completionDelegate:self];
      [self animateLayoutTransition:_transitionContext];
    });
  };

  // TODO ihm: Can we always push the measure to the background thread and remove the parameter from the API?
  if (shouldMeasureAsync) {
    ASPerformBlockOnBackgroundThread(transitionBlock);
  } else {
    transitionBlock();
  }
}

- (void)_completeLayoutCalculation
{
  ASDN::MutexLocker l(_propertyLock);
  [self calculatedLayoutDidChange];

  // We generate placeholders at measureWithSizeRange: time so that a node is guaranteed to have a placeholder ready to go.
  // This is also because measurement is usually asynchronous, but placeholders need to be set up synchronously.
  // First measurement is guaranteed to be before the node is onscreen, so we can create the image async. but still have it appear sync.
  if (_placeholderEnabled && [self _displaysAsynchronously] && self.contents == nil) {
    
    // Zero-sized nodes do not require a placeholder.
    CGSize layoutSize = (_layout ? _layout.size : CGSizeZero);
    if (CGSizeEqualToSize(layoutSize, CGSizeZero)) {
      return;
    }

    if (!_placeholderImage) {
      _placeholderImage = [self placeholderImage];
    }
  }
}

- (void)calculatedLayoutDidChange
{
  // subclass override
}

- (void)cancelLayoutTransitionsInProgress
{
  ASDN::MutexLocker l(_propertyLock);
  if ([self _isTransitionInProgress]) {
    // Cancel transition in progress
    [self _finishOrCancelTransition];
      
    // Tell subnodes to exit layout pending state and clear related properties
    ASDisplayNodePerformBlockOnEverySubnode(self, ^(ASDisplayNode * _Nonnull node) {
      node.hierarchyState &= (~ASHierarchyStateLayoutPending);
    });
  }
}

- (BOOL)usesImplicitHierarchyManagement
{
  ASDN::MutexLocker l(_propertyLock);
  return _usesImplicitHierarchyManagement ? : [[self class] usesImplicitHierarchyManagement];
}

- (void)setUsesImplicitHierarchyManagement:(BOOL)value
{
  ASDN::MutexLocker l(_propertyLock);
  _usesImplicitHierarchyManagement = value;
}

- (BOOL)_isTransitionInProgress
{
  ASDN::MutexLocker l(_propertyLock);
  return _transitionInProgress;
}

/// Starts a new transition and returns the transition id
- (int32_t)_startNewTransition
{
  ASDN::MutexLocker l(_propertyLock);
  _transitionInProgress = YES;
  _transitionID = OSAtomicAdd32(1, &_transitionID);
  return _transitionID;
}

- (void)_finishOrCancelTransition
{
  ASDN::MutexLocker l(_propertyLock);
  _transitionInProgress = NO;
}

- (BOOL)_shouldAbortTransitionWithID:(int32_t)transitionID
{
  ASDN::MutexLocker l(_propertyLock);
  return (!_transitionInProgress || _transitionID != transitionID);
}

- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  [self __layoutSublayouts];
  [context completeTransition:YES];
}

- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context
{
  [_pendingLayoutTransition applySubnodeRemovals];
  [self _completeLayoutCalculation];
  _pendingLayoutTransition = nil;
}

#pragma mark - _ASTransitionContextCompletionDelegate

- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete
{
  [self didCompleteLayoutTransition:context];
  _transitionContext = nil;
}

#pragma mark - Asynchronous display

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
  return _flags.synchronous == NO && _flags.displaysAsynchronously;
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
  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(!((_hierarchyState & ASHierarchyStateRasterized) && _flags.shouldRasterizeDescendants),
                      @"Subnode of a rasterized node should not have redundant shouldRasterizeDescendants enabled");
  return _flags.shouldRasterizeDescendants;
}

- (void)setShouldRasterizeDescendants:(BOOL)shouldRasterize
{
  ASDisplayNodeAssertThreadAffinity(self);
  {
    ASDN::MutexLocker l(_propertyLock);
    
    if (_flags.shouldRasterizeDescendants == shouldRasterize)
      return;
    
    _flags.shouldRasterizeDescendants = shouldRasterize;
  }
  
  if (self.isNodeLoaded) {
    // Recursively tear down or build up subnodes.
    // TODO: When disabling rasterization, preserve rasterized backing store as placeholderImage
    // while the newly materialized subtree finishes rendering.  Then destroy placeholderImage to save memory.
    [self recursivelyClearContents];
    
    ASDisplayNodePerformBlockOnEverySubnode(self, ^(ASDisplayNode *node) {
      if (shouldRasterize) {
        [node enterHierarchyState:ASHierarchyStateRasterized];
        [node __unloadNode];
      } else {
        [node exitHierarchyState:ASHierarchyStateRasterized];
        [node __loadNode];
      }
    });
    if (!shouldRasterize) {
      // At this point all of our subnodes have their layers or views recreated, but we haven't added
      // them to ours yet.  This is because our node is already loaded, and the above recursion
      // is only performed on our subnodes -- not self.
      [self _addSubnodeViewsAndLayers];
    }
    
    if (ASInterfaceStateIncludesVisible(self.interfaceState)) {
      // TODO: Change this to recursivelyEnsureDisplay - but need a variant that does not skip
      // nodes that have shouldBypassEnsureDisplay set (such as image nodes) so they are rasterized.
      [self recursivelyDisplayImmediately];
    }
  } else {
    ASDisplayNodePerformBlockOnEverySubnode(self, ^(ASDisplayNode *node) {
      if (shouldRasterize) {
        [node enterHierarchyState:ASHierarchyStateRasterized];
      } else {
        [node exitHierarchyState:ASHierarchyStateRasterized];
      }
    });
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

- (void)applyPendingViewState
{
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_propertyLock);

  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but implicit hierarchy management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    [self __setNeedsLayout];
  }

  if (self.layerBacked) {
    [_pendingViewState applyToLayer:self.layer];
  } else {
    BOOL specialPropertiesHandling = ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(_flags);
    [_pendingViewState applyToView:self.view withSpecialPropertiesHandling:specialPropertiesHandling];
  }

  [_pendingViewState clearChanges];
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
  
  if ([self _hasDirtyLayout]) {
    return;
  }
  
  [self invalidateCalculatedLayout];
  
  if (_supernode) {
    ASDisplayNode *supernode = _supernode;
    ASDN::MutexUnlocker u(_propertyLock);
    // Cause supernode's layout to be invalidated
    // We need to release the lock to prevent a deadlock
    [supernode setNeedsLayout];
    return;
  }
  
  // This is the root node. Trigger a full measurement pass on *current* thread. Old constrained size is re-used.
  [self measureWithSizeRange:_layout.constrainedSizeRange];

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

- (void)__setNeedsDisplay
{
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(_interfaceState);
  // FIXME: This should not need to recursively display, so create a non-recursive variant.
  // The semantics of setNeedsDisplay (as defined by CALayer behavior) are not recursive.
  if (_layer && !_flags.synchronous && nowDisplay && [self __implementsDisplay]) {
    [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
  }
}

// These private methods ensure that subclasses are not required to call super in order for _renderingSubnodes to be properly managed.

- (void)__layout
{
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_propertyLock);
  CGRect bounds = self.bounds;
  if (CGRectEqualToRect(bounds, CGRectZero)) {
    // Performing layout on a zero-bounds view often results in frame calculations
    // with negative sizes after applying margins, which will cause
    // measureWithSizeRange: on subnodes to assert.
    return;
  }

  // Handle placeholder layer creation in case the size of the node changed after the initial placeholder layer
  // was created
  if ([self _shouldHavePlaceholderLayer]) {
    [self _setupPlaceholderLayerIfNeeded];
  }
  _placeholderLayer.frame = bounds;

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

static inline CATransform3D _calculateTransformFromReferenceToTarget(ASDisplayNode *referenceNode, ASDisplayNode *targetNode)
{
  ASDisplayNode *ancestor = ASDisplayNodeFindClosestCommonAncestor(referenceNode, targetNode);

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
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

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
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

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
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

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
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

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
  
  // This call will apply our .hierarchyState to the new subnode.
  // If we are a managed hierarchy, as in ASCellNode trees, it will also apply our .interfaceState.
  [subnode __setSupernode:self];
  
  if (self.nodeLoaded) {
    // If this node has a view or layer, force the subnode to also create its view or layer and add it to the hierarchy here.
    // Otherwise there is no way for the subnode's view or layer to enter the hierarchy, except recursing down all
    // subnodes on the main thread after the node tree has been created but before the first display (which
    // could introduce performance problems).
    ASPerformBlockOnMainThread(^{
      [self _addSubnodeSubviewOrSublayer:subnode];
    });
  }

  ASDisplayNodeAssert(isMovingEquivalentParents == disableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (isMovingEquivalentParents) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }
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
  [oldSubnode removeFromSupernode];
  
  if (!_subnodes)
    _subnodes = [[NSMutableArray alloc] init];
  [_subnodes insertObject:subnode atIndex:subnodeIndex];
  [subnode __setSupernode:self];
  
  // Don't bother inserting the view/layer if in a rasterized subtree, because there are no layers in the hierarchy and none of this could possibly work.
  if (!_flags.shouldRasterizeDescendants && [self __shouldLoadViewOrLayer]) {
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

  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the hierarchy and none of this could possibly work.
  if (!_flags.shouldRasterizeDescendants && [self __shouldLoadViewOrLayer]) {
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

// NOTE: You must not called this method while holding the receiver's property lock. This may cause deadlocks.
- (void)removeFromSupernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  _propertyLock.lock();
    __weak ASDisplayNode *supernode = _supernode;
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
    BOOL layerBacked = _flags.layerBacked;
    BOOL isNodeLoaded = (layer != nil || view != nil);
  _propertyLock.unlock();

  // Clear supernode's reference to us before removing the view from the hierarchy, as _ASDisplayView
  // will trigger us to clear our _supernode pointer in willMoveToSuperview:nil.
  // This may result in removing the last strong reference, triggering deallocation after this method.
  [supernode _removeSubnode:self];

  if (isNodeLoaded && (supernode == nil || supernode.isNodeLoaded)) {
    ASPerformBlockOnMainThread(^{
      if (layerBacked || supernode.layerBacked) {
        [layer removeFromSuperlayer];
      } else {
        [view removeFromSuperview];
      }
    });
  }
}

- (BOOL)__visibilityNotificationsDisabled
{
  // Currently, this method is only used by the testing infrastructure to verify this internal feature.
  ASDN::MutexLocker l(_propertyLock);
  return _flags.visibilityNotificationsDisabled > 0;
}

- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  return (_hierarchyState & ASHierarchyStateTransitioningSupernodes);
}

- (void)__incrementVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  const size_t maxVisibilityIncrement = (1ULL<<VISIBILITY_NOTIFICATIONS_DISABLED_BITS) - 1ULL;
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled < maxVisibilityIncrement, @"Oops, too many increments of the visibility notifications API");
  if (_flags.visibilityNotificationsDisabled < maxVisibilityIncrement) {
    _flags.visibilityNotificationsDisabled++;
  }
  if (_flags.visibilityNotificationsDisabled == 1) {
    // Must have just transitioned from 0 to 1.  Notify all subnodes that we are in a disabled state.
    [self enterHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

- (void)__decrementVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled > 0, @"Can't decrement past 0");
  if (_flags.visibilityNotificationsDisabled > 0) {
    _flags.visibilityNotificationsDisabled--;
  }
  if (_flags.visibilityNotificationsDisabled == 0) {
    // Must have just transitioned from 1 to 0.  Notify all subnodes that we are no longer in a disabled state.
    // FIXME: This system should be revisited when refactoring and consolidating the implementation of the
    // addSubnode: and insertSubnode:... methods.  As implemented, though logically irrelevant for expected use cases,
    // multiple nodes in the subtree below may have a non-zero visibilityNotification count and still have
    // the ASHierarchyState bit cleared (the only value checked when reading this state).
    [self exitHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

- (void)__enterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"Should not cause recursive __enterHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  ASDN::MutexLocker l(_propertyLock);
  
  if (!_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isEnteringHierarchy = YES;
    _flags.isInHierarchy = YES;
    
    if (_flags.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveWillEnterHierarchy];
    } else {
      [self willEnterHierarchy];
    }
    _flags.isEnteringHierarchy = NO;

    
    // If we don't have contents finished drawing by the time we are on screen, immediately add the placeholder (if it is enabled and we do have something to draw).
    if (self.contents == nil) {
      CALayer *layer = self.layer;
      [layer setNeedsDisplay];
      
      if ([self _shouldHavePlaceholderLayer]) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self _setupPlaceholderLayerIfNeeded];
        _placeholderLayer.opacity = 1.0;
        [CATransaction commit];
        [layer addSublayer:_placeholderLayer];
      }
    }
  }
}

- (void)__exitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"Should not cause recursive __exitHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  ASDN::MutexLocker l(_propertyLock);
  
  if (_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isExitingHierarchy = YES;
    _flags.isInHierarchy = NO;

    [self.asyncLayer cancelAsyncDisplay];

    if (_flags.shouldRasterizeDescendants) {
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
  ASDN::MutexLocker l(_propertyLock);
  return [_subnodes copy];
}

- (ASDisplayNode *)supernode
{
  ASDN::MutexLocker l(_propertyLock);
  return _supernode;
}

// This is a thread-method to return the supernode without causing it to be retained autoreleased.  See -_removeSubnode: for details.
- (ASDisplayNode *)_deallocSafeSupernode
{
  ASDN::MutexLocker l(_propertyLock);
  return _supernode;
}

- (void)__setSupernode:(ASDisplayNode *)newSupernode
{
  BOOL supernodeDidChange = NO;
  ASDisplayNode *oldSupernode = nil;
  {
    ASDN::MutexLocker l(_propertyLock);
    if (_supernode != newSupernode) {
      oldSupernode = _supernode;  // Access supernode properties outside of lock to avoid remote chance of deadlock,
                                  // in case supernode implementation must access one of our properties.
      _supernode = newSupernode;
      supernodeDidChange = YES;
    }
  }
  
  if (supernodeDidChange) {
    // Hierarchy state
    ASHierarchyState stateToEnterOrExit = (newSupernode ? newSupernode.hierarchyState
                                                        : oldSupernode.hierarchyState);
    
    // Rasterized state
    BOOL parentWasOrIsRasterized        = (newSupernode ? newSupernode.shouldRasterizeDescendants
                                                        : oldSupernode.shouldRasterizeDescendants);
    if (parentWasOrIsRasterized) {
      stateToEnterOrExit |= ASHierarchyStateRasterized;
    }
    if (newSupernode) {
      [self enterHierarchyState:stateToEnterOrExit];
    } else {
      // If a node will be removed from the supernode it should go out from the layout pending state to remove all
      // layout pending state related properties on the node
      stateToEnterOrExit |= ASHierarchyStateLayoutPending;
      
      [self exitHierarchyState:stateToEnterOrExit];
    }
    
    // now that we have a supernode, propagate its traits to self.
    ASEnvironmentStatePropagateDown(self, [newSupernode environmentTraitCollection]);
  }
}

// Track that a node will be displayed as part of the current node hierarchy.
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeWillDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  if (!_pendingDisplayNodes) {
    _pendingDisplayNodes = [[NSMutableSet alloc] init];
  }

  [_pendingDisplayNodes addObject:node];
}

// Notify that a node that was pending display finished
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeDidDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  [_pendingDisplayNodes removeObject:node];

  if (_pendingDisplayNodes.count == 0) {
    [self hierarchyDisplayDidFinish];
    
    if (_placeholderLayer.superlayer && ![self placeholderShouldPersist]) {
      void (^cleanupBlock)() = ^{
        [_placeholderLayer removeFromSuperlayer];
      };

      if (_placeholderFadeDuration > 0.0 && ASInterfaceStateIncludesVisible(self.interfaceState)) {
        [CATransaction begin];
        [CATransaction setCompletionBlock:cleanupBlock];
        [CATransaction setAnimationDuration:_placeholderFadeDuration];
        _placeholderLayer.opacity = 0.0;
        [CATransaction commit];
      } else {
        cleanupBlock();
      }
    }
  }
}

/// Helper method to summarize whether or not the node run through the display process
- (BOOL)__implementsDisplay
{
  return _flags.implementsDrawRect || _flags.implementsImageDisplay || _flags.shouldRasterizeDescendants ||
         _flags.implementsInstanceDrawRect || _flags.implementsInstanceImageDisplay;
}

// Helper method to determine if it's save to call setNeedsDisplay on a layer without throwing away the content.
// For details look at the comment on the canCallNeedsDisplayOfLayer flag
- (BOOL)__canCallNeedsDisplayOfLayer
{
  return _flags.canCallNeedsDisplayOfLayer;
}

- (BOOL)placeholderShouldPersist
{
  return NO;
}

- (BOOL)_shouldHavePlaceholderLayer
{
  return (_placeholderEnabled && [self __implementsDisplay]);
}

- (void)_setupPlaceholderLayerIfNeeded
{
  ASDisplayNodeAssertMainThread();

  if (!_placeholderLayer) {
    _placeholderLayer = [CALayer layer];
    // do not set to CGFLOAT_MAX in the case that something needs to be overtop the placeholder
    _placeholderLayer.zPosition = 9999.0;
  }

  if (_placeholderLayer.contents == nil) {
    if (!_placeholderImage) {
      _placeholderImage = [self placeholderImage];
    }
    if (_placeholderImage) {
      BOOL stretchable = !UIEdgeInsetsEqualToEdgeInsets(_placeholderImage.capInsets, UIEdgeInsetsZero);
      if (stretchable) {
        ASDisplayNodeSetupLayerContentsWithResizableImage(_placeholderLayer, _placeholderImage);
      } else {
        _placeholderLayer.contentsScale = self.contentsScale;
        _placeholderLayer.contents = (id)_placeholderImage.CGImage;
      }
    }
  }
}

void recursivelyTriggerDisplayForLayer(CALayer *layer, BOOL shouldBlock)
{
  // This recursion must handle layers in various states:
  // 1. Just added to hierarchy, CA hasn't yet called -display
  // 2. Previously in a hierarchy (such as a working window owned by an Intelligent Preloading class, like ASTableView / ASCollectionView / ASViewController)
  // 3. Has no content to display at all
  // Specifically for case 1), we need to explicitly trigger a -display call now.
  // Otherwise, there is no opportunity to block the main thread after CoreAnimation's transaction commit
  // (even a runloop observer at a late call order will not stop the next frame from compositing, showing placeholders).
  
  ASDisplayNode *node = [layer asyncdisplaykit_node];
  
  if ([node __canCallNeedsDisplayOfLayer]) {
    // Layers for UIKit components that are wrapped wtihin a node needs to be set to be displayed as the contents of
    // the layer get's cleared and would not be recreated otherwise
    [layer setNeedsDisplay];
  }
  
  if ([node __implementsDisplay]) {
    // For layers that do get displayed here, this immediately kicks off the work on the concurrent -[_ASDisplayLayer displayQueue].
    // At the same time, it creates an associated _ASAsyncTransaction, which we can use to block on display completion.  See ASDisplayNode+AsyncDisplay.mm.
    [layer displayIfNeeded];
  }
  
  // Kick off the recursion first, so that all necessary display calls are sent and the displayQueue is full of parallelizable work.
  // NOTE: The docs report that `sublayers` returns a copy but it actually doesn't.
  for (CALayer *sublayer in [layer.sublayers copy]) {
    recursivelyTriggerDisplayForLayer(sublayer, shouldBlock);
  }
  
  if (shouldBlock) {
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
}

- (void)_recursivelyTriggerDisplayAndBlock:(BOOL)shouldBlock
{
  ASDisplayNodeAssertMainThread();
  
  CALayer *layer = self.layer;
  // -layoutIfNeeded is recursive, and even walks up to superlayers to check if they need layout,
  // so we should call it outside of starting the recursion below.  If our own layer is not marked
  // as dirty, we can assume layout has run on this subtree before.
  if ([layer needsLayout]) {
    [layer layoutIfNeeded];
  }
  recursivelyTriggerDisplayForLayer(layer, shouldBlock);
}

- (void)recursivelyEnsureDisplaySynchronously:(BOOL)synchronously
{
  [self _recursivelyTriggerDisplayAndBlock:synchronously];
}

- (void)setShouldBypassEnsureDisplay:(BOOL)shouldBypassEnsureDisplay
{
  _flags.shouldBypassEnsureDisplay = shouldBypassEnsureDisplay;
}

- (BOOL)shouldBypassEnsureDisplay
{
  return _flags.shouldBypassEnsureDisplay;
}

#pragma mark - For Subclasses

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDN::MutexLocker l(_propertyLock);
  if ((_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) || _layoutSpecBlock != NULL) {
    ASLayoutSpec *layoutSpec = [self layoutSpecThatFits:constrainedSize];
    layoutSpec.parent = self; // This causes upward propogation of any non-default layoutable values.
    
    // manually propagate the trait collection here so that any layoutSpec children of layoutSpec will get a traitCollection
    ASEnvironmentStatePropagateDown(layoutSpec, self.environmentTraitCollection);
    
    layoutSpec.isMutable = NO;
    ASLayout *layout = [layoutSpec measureWithSizeRange:constrainedSize];
    // Make sure layoutableObject of the root layout is `self`, so that the flattened layout will be structurally correct.
    BOOL isFinalLayoutable = (layout.layoutableObject != self);
    if (isFinalLayoutable) {
      layout.position = CGPointZero;
      layout = [ASLayout layoutWithLayoutableObject:self constrainedSizeRange:constrainedSize size:layout.size sublayouts:@[layout]];
#if LAYOUT_VALIDATION
      ASLayoutableValidateLayout(layout);
#endif
    }
    return [layout filteredNodeLayoutTree];
  } else {
    // If neither -layoutSpecThatFits: nor -calculateSizeThatFits: is overridden by subclassses, preferredFrameSize should be used,
    // assume that the default implementation of -calculateSizeThatFits: returns it.
    CGSize size = [self calculateSizeThatFits:constrainedSize.max];
    return [ASLayout layoutWithLayoutableObject:self
                           constrainedSizeRange:constrainedSize
                                           size:ASSizeRangeClamp(constrainedSize, size)];
  }
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
    
  ASDN::MutexLocker l(_propertyLock);
  return _preferredFrameSize;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDN::MutexLocker l(_propertyLock);
  
  if (_layoutSpecBlock != NULL) {
    return _layoutSpecBlock(self, constrainedSize);
  }
  
  return nil;
}

- (ASLayout *)calculatedLayout
{
  ASDN::MutexLocker l(_propertyLock);
  return _layout;
}

- (CGSize)calculatedSize
{
  ASDN::MutexLocker l(_propertyLock);
  return _layout.size;
}

- (ASSizeRange)constrainedSizeForCalculatedLayout
{
  ASDN::MutexLocker l(_propertyLock);
  return _layout.constrainedSizeRange;
}

- (void)setLayoutSpecBlock:(ASLayoutSpecBlock)layoutSpecBlock
{
  // For now there should never be a overwrite of layoutSpecThatFits: and a layoutSpecThatFitsBlock: be provided
  ASDisplayNodeAssert(!(_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits), @"Overwriting layoutSpecThatFits: and providing a layoutSpecBlock block is currently not supported");
  
  _layoutSpecBlock = layoutSpecBlock;
}

- (void)setPendingTransitionID:(int32_t)pendingTransitionID
{
  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssertTrue(_pendingTransitionID < pendingTransitionID);
  _pendingTransitionID = pendingTransitionID;
}

- (void)setPreferredFrameSize:(CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(_propertyLock);
  if (! CGSizeEqualToSize(_preferredFrameSize, preferredFrameSize)) {
    _preferredFrameSize = preferredFrameSize;
    self.sizeRange = ASRelativeSizeRangeMake(ASRelativeSizeMakeWithCGSize(_preferredFrameSize), ASRelativeSizeMakeWithCGSize(_preferredFrameSize));
    [self invalidateCalculatedLayout];
  }
}

- (CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(_propertyLock);
  return _preferredFrameSize;
}

- (CGRect)threadSafeBounds
{
  ASDN::MutexLocker l(_propertyLock);
  return _threadSafeBounds;
}

- (void)setThreadSafeBounds:(CGRect)newBounds
{
  ASDN::MutexLocker l(_propertyLock);
  _threadSafeBounds = newBounds;
}

- (UIImage *)placeholderImage
{
  return nil;
}

- (void)invalidateCalculatedLayout
{
  ASDN::MutexLocker l(_propertyLock);

  // This will cause the next call to -measureWithSizeRange: to actually compute a new layout
  // instead of returning the current layout
  _layout.dirty = YES;
}

- (void)__didLoad
{
  ASDN::MutexLocker l(_propertyLock);
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

#pragma mark Hierarchy State

- (void)willEnterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isEnteringHierarchy, @"You should never call -willEnterHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");

  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateInHierarchy;
  }
}

- (void)didExitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isExitingHierarchy, @"You should never call -didExitHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  
  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateNone;
  } else {
    // This case is important when tearing down hierarchies.  We must deliver a visibileStateDidChange:NO callback, as part our API guarantee that this method can be used for
    // things like data analytics about user content viewing.  We cannot call the method in the dealloc as any incidental retain operations in client code would fail.
    // Additionally, it may be that a Standard UIView which is containing us is moving between hierarchies, and we should not send the call if we will be re-added in the
    // same runloop.  Strategy: strong reference (might be the last!), wait one runloop, and confirm we are still outside the hierarchy (both layer-backed and view-backed).
    // TODO: This approach could be optimized by only performing the dispatch for root elements + recursively apply the interface state change. This would require a closer
    // integration with _ASDisplayLayer to ensure that the superlayer pointer has been cleared by this stage (to check if we are root or not), or a different delegate call.
    
    if (ASInterfaceStateIncludesVisible(_interfaceState)) {
      dispatch_async(dispatch_get_main_queue(), ^{
        // This block intentionally retains self.
        ASDN::MutexLocker l(_propertyLock);
        if (!_flags.isInHierarchy && ASInterfaceStateIncludesVisible(_interfaceState)) {
          self.interfaceState = (_interfaceState & ~ASInterfaceStateVisible);
        }
      });
    }
  }
}

#pragma mark Interface State

- (void)clearContents
{
  if (_flags.canClearContentsOfLayer) {
    // No-op if these haven't been created yet, as that guarantees they don't have contents that needs to be released.
    _layer.contents = nil;
  }
  
  _placeholderLayer.contents = nil;
  _placeholderImage = nil;
}

- (void)recursivelyClearContents
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode * _Nonnull node) {
    [node clearContents];
  });
}

- (void)fetchData
{
  // subclass override
}

- (void)setNeedsDataFetch
{
  if (ASInterfaceStateIncludesFetchData(_interfaceState)) {
    [self recursivelyFetchData];
  }
}

- (void)recursivelyFetchData
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode * _Nonnull node) {
    [node fetchData];
  });
}

- (void)clearFetchedData
{
  // subclass override
}

- (void)recursivelyClearFetchedData
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode * _Nonnull node) {
    [node clearFetchedData];
  });
}

- (void)visibilityDidChange:(BOOL)isVisible
{
  // subclass override
}

- (void)visibleStateDidChange:(BOOL)isVisible
{
  // subclass override
}

- (void)displayStateDidChange:(BOOL)inDisplayState
{
  //subclass override
}

- (void)loadStateDidChange:(BOOL)inLoadState
{
  //subclass override
}

/**
 * We currently only set interface state on nodes in table/collection views. For other nodes, if they are
 * in the hierarchy we enable all ASInterfaceState types with `ASInterfaceStateInHierarchy`, otherwise `None`.
 */
- (BOOL)supportsRangeManagedInterfaceState
{
  return ASHierarchyStateIncludesRangeManaged(_hierarchyState);
}

- (ASInterfaceState)interfaceState
{
  ASDN::MutexLocker l(_propertyLock);
  return _interfaceState;
}

- (void)setInterfaceState:(ASInterfaceState)newState
{
  // It should never be possible for a node to be visible but not be allowed / expected to display.
  ASDisplayNodeAssertFalse(ASInterfaceStateIncludesVisible(newState) && !ASInterfaceStateIncludesDisplay(newState));
  ASInterfaceState oldState = ASInterfaceStateNone;
  {
    ASDN::MutexLocker l(_propertyLock);
    if (_interfaceState == newState) {
      return;
    }
    oldState = _interfaceState;
    _interfaceState = newState;
  }
  
  if ((newState & ASInterfaceStateMeasureLayout) != (oldState & ASInterfaceStateMeasureLayout)) {
    // Trigger asynchronous measurement if it is not already cached or being calculated.
  }
  
  // For the FetchData and Display ranges, we don't want to call -clear* if not being managed by a range controller.
  // Otherwise we get flashing behavior from normal UIKit manipulations like navigation controller push / pop.
  // Still, the interfaceState should be updated to the current state of the node; just don't act on the transition.
  
  // Entered or exited data loading state.
  BOOL nowFetchData = ASInterfaceStateIncludesFetchData(newState);
  BOOL wasFetchData = ASInterfaceStateIncludesFetchData(oldState);
  
  if (nowFetchData != wasFetchData) {
    if (nowFetchData) {
      [self fetchData];
      [self loadStateDidChange:YES];
    } else {
      if ([self supportsRangeManagedInterfaceState]) {
        [self clearFetchedData];
      }
      [self loadStateDidChange:NO];
    }
  }

  // Entered or exited contents rendering state.
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(newState);
  BOOL wasDisplay = ASInterfaceStateIncludesDisplay(oldState);

  if (nowDisplay != wasDisplay) {
    if ([self supportsRangeManagedInterfaceState]) {
      if (nowDisplay) {
        // Once the working window is eliminated (ASRangeHandlerRender), trigger display directly here.
        [self setDisplaySuspended:NO];
      } else {
        [self setDisplaySuspended:YES];
        //schedule clear contents on next runloop
        dispatch_async(dispatch_get_main_queue(), ^{
          ASDN::MutexLocker l(_propertyLock);
          if (ASInterfaceStateIncludesDisplay(_interfaceState) == NO) {
            [self clearContents];
          }
        });
      }
    } else {
      // NOTE: This case isn't currently supported as setInterfaceState: isn't exposed externally, and all
      // internal use cases are range-managed.  When a node is visible, don't mess with display - CA will start it.
      if (!ASInterfaceStateIncludesVisible(newState)) {
        // Check __implementsDisplay purely for efficiency - it's faster even than calling -asyncLayer.
        if ([self __implementsDisplay]) {
          if (nowDisplay) {
            [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
          } else {
            [[self asyncLayer] cancelAsyncDisplay];
            //schedule clear contents on next runloop
            dispatch_async(dispatch_get_main_queue(), ^{
              ASDN::MutexLocker l(_propertyLock);
              if (ASInterfaceStateIncludesDisplay(_interfaceState) == NO) {
                [self clearContents];
              }
            });
          }
        }
      }
    }
    
    [self displayStateDidChange:nowDisplay];
  }

  // Became visible or invisible.  When range-managed, this represents literal visibility - at least one pixel
  // is onscreen.  If not range-managed, we can't guarantee more than the node being present in an onscreen window.
  BOOL nowVisible = ASInterfaceStateIncludesVisible(newState);
  BOOL wasVisible = ASInterfaceStateIncludesVisible(oldState);

  if (nowVisible != wasVisible) {
    [self visibleStateDidChange:nowVisible];
    [self visibilityDidChange:nowVisible];   //TODO: remove once this method has been deprecated
  }

  [self interfaceStateDidChange:newState fromState:oldState];
}

- (void)interfaceStateDidChange:(ASInterfaceState)newState fromState:(ASInterfaceState)oldState
{
  // subclass hook
}

- (void)enterInterfaceState:(ASInterfaceState)interfaceState
{
  if (interfaceState == ASInterfaceStateNone) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    node.interfaceState |= interfaceState;
  });
}

- (void)exitInterfaceState:(ASInterfaceState)interfaceState
{
  if (interfaceState == ASInterfaceStateNone) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    node.interfaceState &= (~interfaceState);
  });
}

- (void)recursivelySetInterfaceState:(ASInterfaceState)newInterfaceState
{
  // Instead of each node in the recursion assuming it needs to schedule itself for display,
  // setInterfaceState: skips this when handling range-managed nodes (our whole subtree has this set).
  // If our range manager intends for us to be displayed right now, and didn't before, get started!
  BOOL shouldScheduleDisplay = [self supportsRangeManagedInterfaceState] && [self shouldScheduleDisplayWithNewInterfaceState:newInterfaceState];
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    node.interfaceState = newInterfaceState;
  });
  if (shouldScheduleDisplay) {
    [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
  }
}

- (BOOL)shouldScheduleDisplayWithNewInterfaceState:(ASInterfaceState)newInterfaceState
{
  BOOL willDisplay = ASInterfaceStateIncludesDisplay(newInterfaceState);
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(self.interfaceState);
  return willDisplay && (willDisplay != nowDisplay);
}

- (ASHierarchyState)hierarchyState
{
  ASDN::MutexLocker l(_propertyLock);
  return _hierarchyState;
}

- (void)setHierarchyState:(ASHierarchyState)newState
{
  ASHierarchyState oldState = ASHierarchyStateNormal;
  {
    ASDN::MutexLocker l(_propertyLock);
    if (_hierarchyState == newState) {
      return;
    }
    oldState = _hierarchyState;
    _hierarchyState = newState;
  }
  
  // Entered or exited contents rendering state.
  if ((newState & ASHierarchyStateRangeManaged) != (oldState & ASHierarchyStateRangeManaged)) {
    if (newState & ASHierarchyStateRangeManaged) {
      [self enterInterfaceState:self.supernode.interfaceState];
    } else {
      // The case of exiting a range-managed state should be fairly rare.  Adding or removing the node
      // to a view hierarchy will cause its interfaceState to be either fully set or unset (all fields),
      // but because we might be about to be added to a view hierarchy, exiting the interface state now
      // would cause inefficient churn.  The tradeoff is that we may not clear contents / fetched data
      // for nodes that are removed from a managed state and then retained but not used (bad idea anyway!)
    }
  }
  
  if ((newState & ASHierarchyStateLayoutPending) != (oldState & ASHierarchyStateLayoutPending)) {
    if (newState & ASHierarchyStateLayoutPending) {
      // Entering layout pending state
    } else {
      // Leaving layout pending state, reset related properties
      {
        ASDN::MutexLocker l(_propertyLock);
        _pendingTransitionID = ASLayoutableContextInvalidTransitionID;
        _pendingLayoutTransition = nil;
      }
    }
  }
  
  if (newState != oldState) {
    LOG(@"setHierarchyState: oldState = %lu, newState = %lu", (unsigned long)oldState, (unsigned long)newState);
  }
}

- (void)enterHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    node.hierarchyState |= hierarchyState;
  });
}

- (void)exitHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    node.hierarchyState &= (~hierarchyState);
  });
}

- (void)_applyPendingLayoutContext
{
  ASDN::MutexLocker l(_propertyLock);
  if (_pendingLayoutTransition) {
    [self _applyLayout:_pendingLayoutTransition.pendingLayout layoutTransition:_pendingLayoutTransition];
    _pendingLayoutTransition = nil;
  }
}

- (void)_applyLayout:(ASLayout *)layout layoutTransition:(ASLayoutTransition *)layoutTransition
{
  ASDN::MutexLocker l(_propertyLock);
  _layout = layout;
  
  ASDisplayNodeAssertTrue(layout.layoutableObject == self);
  ASDisplayNodeAssertTrue(layout.size.width >= 0.0);
  ASDisplayNodeAssertTrue(layout.size.height >= 0.0);
  
  if (layoutTransition == nil || self.usesImplicitHierarchyManagement == NO) {
    return;
  }

  // Trampoline to the main thread if necessary
  if (ASDisplayNodeThreadIsMain() == NO && layoutTransition.isSynchronous == NO) {

    // Subnode insertions and removals need to happen always on the main thread if at least one subnode is already loaded
    ASPerformBlockOnMainThread(^{
      [layoutTransition startTransition];
    });
    
    return;
  }
  
  [layoutTransition startTransition];
}

- (void)layout
{
  ASDisplayNodeAssertMainThread();

  if ([self _hasDirtyLayout]) {
    return;
  }
  
  [self __layoutSublayouts];
}

- (void)__layoutSublayouts
{
  for (ASLayout *subnodeLayout in _layout.sublayouts) {
    ((ASDisplayNode *)subnodeLayout.layoutableObject).frame = [subnodeLayout frame];
  }
}

- (void)displayWillStart
{
  ASDisplayNodeAssertMainThread();

  // in case current node takes longer to display than it's subnodes, treat it as a dependent node
  [self _pendingNodeWillDisplay:self];

  [_supernode subnodeDisplayWillStart:self];
}

- (void)displayDidFinish
{
  ASDisplayNodeAssertMainThread();
  
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
  ASDN::MutexLocker l(_propertyLock);
  if (contentsScale != self.contentsScaleForDisplay) {
    self.contentsScaleForDisplay = contentsScale;
    [self setNeedsDisplay];
  }
}

- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, ^(ASDisplayNode *node) {
    [node setNeedsDisplayAtScale:contentsScale];
  });
}

- (void)hierarchyDisplayDidFinish
{
  // subclass hook
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

- (void)_applyPendingStateToViewOrLayer
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"must have a view or layer");

  // If no view/layer properties were set before the view/layer were created, _pendingViewState will be nil and the default values
  // for the view/layer are still valid.
  ASDN::MutexLocker l(_propertyLock);

  [self applyPendingViewState];

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
- (ASDisplayNode *)_supernodeWithClass:(Class)supernodeClass checkViewHierarchy:(BOOL)checkViewHierarchy
{
  ASDisplayNode *supernode = self.supernode;
  while (supernode) {
    if ([supernode isKindOfClass:supernodeClass])
      return supernode;
    supernode = supernode.supernode;
  }
  if (!checkViewHierarchy) {
    return nil;
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

// TODO: Replace this with ASDisplayNodePerformBlockOnEveryNode or a variant with a condition / test block.
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

  if ([self __implementsDisplay]) {
    // Display start and finish methods needs to happen on the main thread
    ASPerformBlockOnMainThread(^{
      if (flag) {
        [_supernode subnodeDisplayDidFinish:self];
      } else {
        [_supernode subnodeDisplayWillStart:self];
      }
    });
  }
}

- (BOOL)shouldAnimateSizeChanges
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _flags.shouldAnimateSizeChanges;
}

-(void)setShouldAnimateSizeChanges:(BOOL)shouldAnimateSizeChanges
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  _flags.shouldAnimateSizeChanges = shouldAnimateSizeChanges;
}

static const char *ASDisplayNodeDrawingPriorityKey = "ASDrawingPriority";

- (void)setDrawingPriority:(NSInteger)drawingPriority
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  if (drawingPriority == ASDefaultDrawingPriority) {
    _flags.hasCustomDrawingPriority = NO;
    objc_setAssociatedObject(self, ASDisplayNodeDrawingPriorityKey, nil, OBJC_ASSOCIATION_ASSIGN);
  } else {
    _flags.hasCustomDrawingPriority = YES;
    objc_setAssociatedObject(self, ASDisplayNodeDrawingPriorityKey, @(drawingPriority), OBJC_ASSOCIATION_RETAIN);
  }
}

-(NSInteger)drawingPriority
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  if (!_flags.hasCustomDrawingPriority)
    return ASDefaultDrawingPriority;
  else
    return [objc_getAssociatedObject(self, ASDisplayNodeDrawingPriorityKey) integerValue];
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

- (id<ASLayoutable>)finalLayoutable
{
  return self;
}


#pragma mark - ASEnvironment

- (ASEnvironmentState)environmentState
{
  return _environmentState;
}

- (void)setEnvironmentState:(ASEnvironmentState)environmentState
{
  ASEnvironmentTraitCollection oldTraitCollection = _environmentState.environmentTraitCollection;
  _environmentState = environmentState;
  
  if (ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(oldTraitCollection, _environmentState.environmentTraitCollection) == NO) {
    [self asyncTraitCollectionDidChange];
  }
}

- (ASDisplayNode *)parent
{
  return self.supernode;
}

- (NSArray<ASDisplayNode *> *)children
{
  return self.subnodes;
}

- (BOOL)supportsUpwardPropagation
{
  return ASEnvironmentStatePropagationEnabled();
}

- (BOOL)supportsTraitsCollectionPropagation
{
  return ASEnvironmentStateTraitCollectionPropagationEnabled();
}

- (ASEnvironmentTraitCollection)environmentTraitCollection
{
  return _environmentState.environmentTraitCollection;
}

- (void)setEnvironmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  if (ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(environmentTraitCollection, _environmentState.environmentTraitCollection) == NO) {
    _environmentState.environmentTraitCollection = environmentTraitCollection;
    [self asyncTraitCollectionDidChange];
  }
}

ASEnvironmentLayoutOptionsForwarding
ASEnvironmentLayoutExtensibilityForwarding

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(_propertyLock);
  return [ASTraitCollection traitCollectionWithASEnvironmentTraitCollection:self.environmentTraitCollection];
}

- (void)asyncTraitCollectionDidChange
{

}

#if TARGET_OS_TV
#pragma mark - UIFocusEnvironment Protocol (tvOS)

- (void)setNeedsFocusUpdate
{
  
}

- (void)updateFocusIfNeeded
{
  
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context
{
  return NO;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator
{
  
}

- (UIView *)preferredFocusedView
{
  if (self.nodeLoaded) {
    return self.view;
  } else {
    return nil;
  }
}
#endif
@end

@implementation ASDisplayNode (Debugging)

- (NSString *)description
{
  if (self.name) {
    return [NSString stringWithFormat:@"<%@ %p name = %@>", self.class, self, self.name];
  } else {
    return [super description];
  }
}

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

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, node, OBJC_ASSOCIATION_ASSIGN); // Weak reference to avoid cycle, since the node retains the view.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  return objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
}

@end

@implementation CALayer (ASDisplayNodeInternal)

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, node, OBJC_ASSOCIATION_ASSIGN); // Weak reference to avoid cycle, since the node retains the layer.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  return objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
}

@end

@implementation UIView (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)subnode
{
  if (subnode.layerBacked) {
    // Call -addSubnode: so that we use the asyncdisplaykit_node path if possible.
    [self.layer addSubnode:subnode];
  } else {
    ASDisplayNode *selfNode = self.asyncdisplaykit_node;
    if (selfNode) {
      [selfNode addSubnode:subnode];
    } else {
      [self addSubview:subnode.view];
    }
  }
}

@end

@implementation CALayer (AsyncDisplayKit)

- (void)addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNode *selfNode = self.asyncdisplaykit_node;
  if (selfNode) {
    [selfNode addSubnode:subnode];
  } else {
    [self addSublayer:subnode.layer];
  }
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
