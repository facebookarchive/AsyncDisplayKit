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
#import "ASDimension.h"
#import "ASLayoutElementStylePrivate.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"
#import "ASLayoutSpec.h"
#import "ASCellNode+Internal.h"
#import "ASWeakProxy.h"

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

#if ASDisplayNodeLoggingEnabled
  #define LOG(...) NSLog(__VA_ARGS__)
#else
  #define LOG(...)
#endif

// Conditionally time these scopes to our debug ivars (only exist in debug/profile builds)
#if TIME_DISPLAYNODE_OPS
#define TIME_SCOPED(outVar) ASDN::ScopeTimer t(outVar)
#else
#define TIME_SCOPED(outVar)
#endif

@implementation ASDisplayNode

@dynamic layoutElementType;

@synthesize name = _name;
@synthesize isFinalLayoutElement = _isFinalLayoutElement;
@synthesize threadSafeBounds = _threadSafeBounds;
@synthesize layoutSpecBlock = _layoutSpecBlock;

static BOOL suppressesInvalidCollectionUpdateExceptions = NO;

+ (BOOL)suppressesInvalidCollectionUpdateExceptions
{
  return suppressesInvalidCollectionUpdateExceptions;
}

+ (void)setSuppressesInvalidCollectionUpdateExceptions:(BOOL)suppresses
{
  suppressesInvalidCollectionUpdateExceptions = suppresses;
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
  ASDN::MutexLocker l(node->__instanceLock__);
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
    
    // Subclasses should never override these. Use unused to prevent warnings
    __unused NSString *classString = NSStringFromClass(self);
    
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measure:)), @"Subclass %@ must not override measure: method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange: method. Instead overwrite calculateLayoutThatFits:", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:)), @"Subclass %@ must not override layoutThatFits: method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:parentSize:)), @"Subclass %@ must not override layoutThatFits:parentSize method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearContents)), @"Subclass %@ must not override recursivelyClearContents method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearFetchedData)), @"Subclass %@ must not override recursivelyClearFetchedData method", classString);
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
  
  
#if DEBUG
  // Check if subnodes where modified during layoutSpecThatFits:
  if (self == [ASDisplayNode class] || ASSubclassOverridesSelector([ASDisplayNode class], self, @selector(layoutSpecThatFits:)))
  {
    __block IMP originalLayoutSpecThatFitsIMP = ASReplaceMethodWithBlock(self, @selector(layoutSpecThatFits:), ^(ASDisplayNode *_self, ASSizeRange sizeRange) {
      NSArray *oldSubnodes = _self.subnodes;
      ASLayoutSpec *layoutSpec = ((ASLayoutSpec *( *)(id, SEL, ASSizeRange))originalLayoutSpecThatFitsIMP)(_self, @selector(layoutSpecThatFits:), sizeRange);
      NSArray *subnodes = _self.subnodes;
      ASDisplayNodeAssert(oldSubnodes.count == subnodes.count, @"Adding or removing nodes in layoutSpecThatFits: is verboten.");
      for (NSInteger i = 0; i < oldSubnodes.count; i++) {
        ASDisplayNodeAssert(oldSubnodes[i] == subnodes[i], @"Adding and removing nodes in layoutSpecThatFits: is verboten.");
      }
      return layoutSpec;
    });
  }
#endif

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
  _eventLogHead = -1;
  _contentsScaleForDisplay = ASScreenScale();
  
  _environmentState = ASEnvironmentStateMakeDefault();
  
  _calculatedDisplayNodeLayout = std::make_shared<ASDisplayNodeLayout>();
  
  _defaultLayoutTransitionDuration = 0.2;
  _defaultLayoutTransitionDelay = 0.0;
  _defaultLayoutTransitionOptions = UIViewAnimationOptionBeginFromCurrentState;
  
  _flags.canClearContentsOfLayer = YES;
  _flags.canCallSetNeedsDisplayOfLayer = YES;
  ASDisplayNodeLogEvent(self, @"init");
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
  _flags.synchronous = YES;
  if (didLoadBlock != nil) {
    _onDidLoadBlocks = [NSMutableArray arrayWithObject:didLoadBlock];
  }
  
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
  _flags.synchronous = YES;
  _flags.layerBacked = YES;
  if (didLoadBlock != nil) {
    _onDidLoadBlocks = [NSMutableArray arrayWithObject:didLoadBlock];
  }
  
  return self;
}

- (void)onDidLoad:(ASDisplayNodeDidLoadBlock)body
{
  ASDN::MutexLocker l(__instanceLock__);
  if ([self _isNodeLoaded]) {
    ASDisplayNodeFailAssert(@"Attempt to call %@ on node after it was loaded. Node: %@", NSStringFromSelector(_cmd), self);
    return;
  }
  
  if (_onDidLoadBlocks == nil) {
    _onDidLoadBlocks = [NSMutableArray arrayWithObject:body];
  } else {
    [_onDidLoadBlocks addObject:body];
  }
}

- (void)dealloc
{
  ASDisplayNodeAssertMainThread();
  // Synchronous nodes may not be able to call the hierarchy notifications, so only enforce for regular nodes.
  ASDisplayNodeAssert(_flags.synchronous || !ASInterfaceStateIncludesVisible(_interfaceState), @"Node should always be marked invisible before deallocating. Node: %@", self);
  
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
  _layer = nil;

  // TODO: Remove this? If supernode isn't already nil, this method isn't dealloc-safe anyway.
  [self __setSupernode:nil];
  _pendingViewState = nil;

  _pendingDisplayNodes = nil;
}

#pragma mark - Core

- (void)__unloadNode
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self isNodeLoaded], @"Implementation shouldn't call __unloadNode if not loaded: %@", self);
  ASDisplayNodeAssert(_flags.synchronous == NO, @"Node created using -initWithViewBlock:/-initWithLayerBlock: cannot be unloaded. Node: %@", self);
  ASDN::MutexLocker l(__instanceLock__);

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

- (UIView *)_viewToLoad
{
  UIView *view;
  ASDN::MutexLocker l(__instanceLock__);

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
  if (_flags.synchronous && [_viewClass isSubclassOfClass:[UIImageView class]]) {
    _flags.canClearContentsOfLayer = NO;
    _flags.canCallSetNeedsDisplayOfLayer = NO;
  }

  return view;
}

- (CALayer *)_layerToLoad
{
  CALayer *layer;
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);

  if (self._isDeallocating) {
    return;
  }

  if (![self __shouldLoadViewOrLayer]) {
    return;
  }

  if (isLayerBacked) {
    TIME_SCOPED(_debugTimeToCreateView);
    _layer = [self _layerToLoad];
    static int ASLayerDelegateAssociationKey;

    /**
     * CALayer's .delegate property is documented to be weak, but the implementation is actually assign.
     * Because our layer may survive longer than the node (e.g. if someone else retains it, or if the node
     * begins deallocation on a background thread and it waiting for the -dealloc call to reach main), the only
     * way to avoid a dangling pointer is to use a weak proxy.
     */
    ASWeakProxy *instance = [ASWeakProxy weakProxyWithTarget:self];
    _layer.delegate = (id<CALayerDelegate>)instance;
    objc_setAssociatedObject(_layer, &ASLayerDelegateAssociationKey, instance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

#if ASDISPLAYNODE_EVENTLOG_ENABLE
- (void)_logEventWithBacktrace:(NSArray<NSString *> *)backtrace format:(NSString *)format, ...
{
  va_list args;
  va_start(args, format);
  ASTraceEvent *event = [[ASTraceEvent alloc] initWithObject:self
                                                   backtrace:backtrace
                                                      format:format
                                                   arguments:args];
  va_end(args);

  ASDN::MutexLocker l(__instanceLock__);
  // Create the array if needed.
  if (_eventLog == nil) {
    _eventLog = [NSMutableArray arrayWithCapacity:ASDISPLAYNODE_EVENTLOG_CAPACITY];
  }

	// Increment the head index.
  _eventLogHead = (_eventLogHead + 1) % ASDISPLAYNODE_EVENTLOG_CAPACITY;
  if (_eventLogHead < _eventLog.count) {
    [_eventLog replaceObjectAtIndex:_eventLogHead withObject:event];
  } else {
    [_eventLog insertObject:event atIndex:_eventLogHead];
  }
}

- (NSArray<ASTraceEvent *> *)eventLog
{
  ASDN::MutexLocker l(__instanceLock__);
  NSUInteger tail = (_eventLogHead + 1);
  NSUInteger count = _eventLog.count;

  NSMutableArray<ASTraceEvent *> *result = [NSMutableArray array];

  // Start from `tail` and go through array, wrapping around when we exceed end index.
  for (NSUInteger actualIndex = 0; actualIndex < ASDISPLAYNODE_EVENTLOG_CAPACITY; actualIndex++) {
    NSInteger ringIndex = (tail + actualIndex) % ASDISPLAYNODE_EVENTLOG_CAPACITY;
    if (ringIndex < count) {
      [result addObject:_eventLog[ringIndex]];
    }
  }
  return result;
}
#endif

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
  ASDN::MutexLocker l(__instanceLock__);
  return [_layer isKindOfClass:[_ASDisplayLayer class]] ? (_ASDisplayLayer *)_layer : nil;
}

- (BOOL)isNodeLoaded
{
  if (ASDisplayNodeThreadIsMain()) {
    // Because the view and layer can only be created and destroyed on Main, that is also the only thread
    // where the state of this property can change. As an optimization, we can avoid locking.
    return [self _isNodeLoaded];
  } else {
    ASDN::MutexLocker l(__instanceLock__);
    return [self _isNodeLoaded];
  }
}

- (BOOL)_isNodeLoaded
{
  return (_view != nil || (_layer != nil && _flags.layerBacked));
}

- (NSString *)name
{
  ASDN::MutexLocker l(__instanceLock__);
  return _name;
}

- (void)setName:(NSString *)name
{
  ASDN::MutexLocker l(__instanceLock__);
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

  ASDN::MutexLocker l(__instanceLock__);
  ASDisplayNodeAssert(!_view && !_layer, @"Cannot change isLayerBacked after layer or view has loaded");
  ASDisplayNodeAssert(!_viewBlock && !_layerBlock, @"Cannot change isLayerBacked when a layer or view block is provided");
  ASDisplayNodeAssert(!_viewClass && !_layerClass, @"Cannot change isLayerBacked when a layer or view class is provided");

  if (isLayerBacked != _flags.layerBacked && !_view && !_layer) {
    _flags.layerBacked = isLayerBacked;
  }
}

- (BOOL)isLayerBacked
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.layerBacked;
}

#pragma mark - Style

- (ASLayoutElementStyle *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_style == nil) {
    _style = [[ASLayoutElementStyle alloc] init];
  }
  return _style;
}

- (instancetype)styledWithBlock:(void (^)(ASLayoutElementStyle *style))styleBlock
{
  styleBlock(self.style);
  return self;
}

#pragma mark - Layout

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return [self measureWithSizeRange:constrainedSize];
#pragma clang diagnostic pop
}

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  ASDN::MutexLocker l(__instanceLock__);

  if ([self shouldCalculateLayoutWithConstrainedSize:constrainedSize parentSize:parentSize] == NO) {
    ASDisplayNodeAssertNotNil(_calculatedDisplayNodeLayout->layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _layout should not be nil! %@", self);
    return _calculatedDisplayNodeLayout->layout ? : [ASLayout layoutWithLayoutElement:self size:{0, 0}];
  }
  
  [self cancelLayoutTransition];
  
  // Prepare for layout transition
  auto previousLayout = _calculatedDisplayNodeLayout;
  auto pendingLayout = std::make_shared<ASDisplayNodeLayout>(
    [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize],
    constrainedSize,
    parentSize
  );
  _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                        pendingLayout:pendingLayout
                                                       previousLayout:previousLayout];
  
  // Only complete the pending layout transition if the node is not a subnode of a node that is currently
  // in a layout transition
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO) {
    // Complete the pending layout transition immediately
    [self _completePendingLayoutTransition];
  }
  
  ASDisplayNodeAssertNotNil(pendingLayout->layout, @"-[ASDisplayNode layoutThatFits:parentSize:] newLayout should not be nil! %@", self);
  return pendingLayout->layout;
}

- (BOOL)shouldCalculateLayoutWithConstrainedSize:(ASSizeRange)constrainedSize parentSize:(CGSize)parentSize
{
  ASDN::MutexLocker l(__instanceLock__);

  // Don't remeasure if in layout pending state and a new transition already started
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    ASLayoutElementContext context =  ASLayoutElementGetCurrentContext();
    if (ASLayoutElementContextIsNull(context) || _pendingTransitionID != context.transitionID) {
      return NO;
    }
  }
  
  // Check if display node layout is still valid
  return _calculatedDisplayNodeLayout->isValidForConstrainedSizeParentSize(constrainedSize, parentSize) == NO;
}

- (ASLayoutElementType)layoutElementType
{
  return ASLayoutElementTypeDisplayNode;
}

- (BOOL)canLayoutAsynchronous
{
  return !self.isNodeLoaded;
}

#pragma mark - Automatic Hierarchy

- (BOOL)automaticallyManagesSubnodes
{
  ASDN::MutexLocker l(__instanceLock__);
  return _automaticallyManagesSubnodes;
}

- (void)setAutomaticallyManagesSubnodes:(BOOL)automaticallyManagesSubnodes
{
  ASDN::MutexLocker l(__instanceLock__);
  _automaticallyManagesSubnodes = automaticallyManagesSubnodes;
}

#pragma mark - Layout Transition

- (void)transitionLayoutWithAnimation:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  if (_calculatedDisplayNodeLayout->layout == nil) {
    // No measure pass happened before, it's not possible to reuse the constrained size for the transition
    // Using CGSizeZero for the sizeRange can cause negative values in client layout code.
    return;
  }
  
  [self invalidateCalculatedLayout];
  [self transitionLayoutWithSizeRange:_calculatedDisplayNodeLayout->constrainedSize
                             animated:animated
                   shouldMeasureAsync:shouldMeasureAsync
                measurementCompletion:completion];
  
}

- (void)transitionLayoutWithSizeRange:(ASSizeRange)constrainedSize
                             animated:(BOOL)animated
                   shouldMeasureAsync:(BOOL)shouldMeasureAsync
                measurementCompletion:(void(^)())completion
{
  // Passed constrainedSize is the the same as the node's current constrained size it's a noop
  ASDisplayNodeAssertMainThread();
  if ([self shouldCalculateLayoutWithConstrainedSize:constrainedSize parentSize:constrainedSize.max] == NO) {
    return;
  }
  
  {
    ASDN::MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO, @"Can't start a transition when one of the supernodes is performing one.");
  }

  int32_t transitionID = [self _startNewTransition];
  
  // Move all subnodes in a pending state
  ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
    ASDisplayNodeAssert([node _isTransitionInProgress] == NO, @"Can't start a transition when one of the subnodes is performing one.");
    node.hierarchyState |= ASHierarchyStateLayoutPending;
    node.pendingTransitionID = transitionID;
  });
  
  void (^transitionBlock)(void) = ^{
    if ([self _shouldAbortTransitionWithID:transitionID]) {
      return;
    }
    
    ASLayout *newLayout;
    {
      ASLayoutElementSetCurrentContext(ASLayoutElementContextMake(transitionID, NO));

      ASDN::MutexLocker l(__instanceLock__);
      BOOL automaticallyManagesSubnodesDisabled = (self.automaticallyManagesSubnodes == NO);
      self.automaticallyManagesSubnodes = YES; // Temporary flag for 1.9.x
      newLayout = [self calculateLayoutThatFits:constrainedSize
                               restrictedToSize:self.style.size
                           relativeToParentSize:constrainedSize.max];
      if (automaticallyManagesSubnodesDisabled) {
        self.automaticallyManagesSubnodes = NO; // Temporary flag for 1.9.x
      }
      
      ASLayoutElementClearCurrentContext();
    }
    
    if ([self _shouldAbortTransitionWithID:transitionID]) {
      return;
    }
    
    ASPerformBlockOnMainThread(^{
      // Grab __instanceLock__ here to make sure this transition isn't invalidated
      // right after it passed the validation test and before it proceeds
      ASDN::MutexLocker l(__instanceLock__);

      if ([self _shouldAbortTransitionWithID:transitionID]) {
        return;
      }

      // Update display node layout
      auto previousLayout = _calculatedDisplayNodeLayout;
      auto pendingLayout = std::make_shared<ASDisplayNodeLayout>(
        newLayout,
        constrainedSize,
        constrainedSize.max
      );
      [self setCalculatedDisplayNodeLayout:pendingLayout];
      
      // Apply complete layout transitions for all subnodes
      ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
        [node _completePendingLayoutTransition];
        node.hierarchyState &= (~ASHierarchyStateLayoutPending);
      });
        
      [self _finishOrCancelTransition];
      
      // Measurement pass completion
      if (completion) {
        completion();
      }
      
      // Setup pending layout transition for animation
      _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                            pendingLayout:pendingLayout
                                                           previousLayout:previousLayout];
      // Setup context for pending layout transition. we need to hold a strong reference to the context
      _pendingLayoutTransitionContext = [[_ASTransitionContext alloc] initWithAnimation:animated
                                                                         layoutDelegate:_pendingLayoutTransition
                                                                     completionDelegate:self];
      
      // Apply the subnode insertion immediately to be able to animate the nodes
      [_pendingLayoutTransition applySubnodeInsertions];
      
      // Kick off animating the layout transition
      [self animateLayoutTransition:_pendingLayoutTransitionContext];
    });
  };
  
  if (shouldMeasureAsync) {
    ASPerformBlockOnBackgroundThread(transitionBlock);
  } else {
    transitionBlock();
  }
}

- (void)cancelLayoutTransition
{
  ASDN::MutexLocker l(__instanceLock__);
  if ([self _isTransitionInProgress]) {
    // Cancel transition in progress
    [self _finishOrCancelTransition];
      
    // Tell subnodes to exit layout pending state and clear related properties
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
      node.hierarchyState &= (~ASHierarchyStateLayoutPending);
    });
  }
}

- (BOOL)_isTransitionInProgress
{
  ASDN::MutexLocker l(__instanceLock__);
  return _transitionInProgress;
}

/// Starts a new transition and returns the transition id
- (int32_t)_startNewTransition
{
  ASDN::MutexLocker l(__instanceLock__);
  _transitionInProgress = YES;
  _transitionID = OSAtomicAdd32(1, &_transitionID);
  return _transitionID;
}

- (void)_finishOrCancelTransition
{
  ASDN::MutexLocker l(__instanceLock__);
  _transitionInProgress = NO;
}

- (BOOL)_shouldAbortTransitionWithID:(int32_t)transitionID
{
  ASDN::MutexLocker l(__instanceLock__);
  return (!_transitionInProgress || _transitionID != transitionID);
}

#pragma mark Layout Transition API

- (void)setDefaultLayoutTransitionDuration:(NSTimeInterval)defaultLayoutTransitionDuration
{
  ASDN::MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionDuration = defaultLayoutTransitionDuration;
}

- (NSTimeInterval)defaultLayoutTransitionDuration
{
  ASDN::MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionDuration;
}

- (void)setDefaultLayoutTransitionDelay:(NSTimeInterval)defaultLayoutTransitionDelay
{
  ASDN::MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionDelay = defaultLayoutTransitionDelay;
}

- (NSTimeInterval)defaultLayoutTransitionDelay
{
  ASDN::MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionDelay;
}

- (void)setDefaultLayoutTransitionOptions:(UIViewAnimationOptions)defaultLayoutTransitionOptions
{
  ASDN::MutexLocker l(__instanceLock__);
  _defaultLayoutTransitionOptions = defaultLayoutTransitionOptions;
}

- (UIViewAnimationOptions)defaultLayoutTransitionOptions
{
  ASDN::MutexLocker l(__instanceLock__);
  return _defaultLayoutTransitionOptions;
}

/*
 * Hook for subclasses to perform an animation based on the given ASContextTransitioning. By default a fade in and out
 * animation is provided.
 */
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  if ([context isAnimated] == NO) {
    [self __layoutSublayouts];
    [context completeTransition:YES];
    return;
  }
 
  ASDisplayNode *node = self;
  
  NSAssert(node.isNodeLoaded == YES, @"Invalid node state");
  
  NSArray<ASDisplayNode *> *removedSubnodes = [context removedSubnodes];
  NSMutableArray<UIView *> *removedViews = [NSMutableArray array];
  NSMutableArray<ASDisplayNode *> *insertedSubnodes = [[context insertedSubnodes] mutableCopy];
  NSMutableArray<ASDisplayNode *> *movedSubnodes = [NSMutableArray array];
  
  for (ASDisplayNode *subnode in [context subnodesForKey:ASTransitionContextToLayoutKey]) {
    if ([insertedSubnodes containsObject:subnode] == NO) {
      // This is an existing subnode, check if it is resized, moved or both
      CGRect fromFrame = [context initialFrameForNode:subnode];
      CGRect toFrame = [context finalFrameForNode:subnode];
      if (CGSizeEqualToSize(fromFrame.size, toFrame.size) == NO) {
        // To crossfade resized subnodes, show a snapshot of it on top.
        // The node itself can then be treated as a newly-inserted one.
        UIView *snapshotView = [subnode.view snapshotViewAfterScreenUpdates:YES];
        snapshotView.frame = [context initialFrameForNode:subnode];
        snapshotView.alpha = 1;
        
        [node.view insertSubview:snapshotView aboveSubview:subnode.view];
        [removedViews addObject:snapshotView];
        
        [insertedSubnodes addObject:subnode];
      }
      if (CGPointEqualToPoint(fromFrame.origin, toFrame.origin) == NO) {
        [movedSubnodes addObject:subnode];
      }
    }
  }
  
  for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
    insertedSubnode.frame = [context finalFrameForNode:insertedSubnode];
    insertedSubnode.alpha = 0;
  }

  [UIView animateWithDuration:self.defaultLayoutTransitionDuration delay:self.defaultLayoutTransitionDelay options:self.defaultLayoutTransitionOptions animations:^{
    // Fade removed subnodes and views out
    for (ASDisplayNode *removedSubnode in removedSubnodes) {
      removedSubnode.alpha = 0;
    }
    for (UIView *removedView in removedViews) {
      removedView.alpha = 0;
    }
    
    // Fade inserted subnodes in
    for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
      insertedSubnode.alpha = 1;
    }
    
    // Update frame of self and moved subnodes
    CGSize fromSize = [context layoutForKey:ASTransitionContextFromLayoutKey].size;
    CGSize toSize = [context layoutForKey:ASTransitionContextToLayoutKey].size;
    BOOL isResized = (CGSizeEqualToSize(fromSize, toSize) == NO);
    if (isResized == YES) {
      CGPoint position = node.frame.origin;
      node.frame = CGRectMake(position.x, position.y, toSize.width, toSize.height);
    }
    for (ASDisplayNode *movedSubnode in movedSubnodes) {
      movedSubnode.frame = [context finalFrameForNode:movedSubnode];
    }
  } completion:^(BOOL finished) {
    for (UIView *removedView in removedViews) {
      [removedView removeFromSuperview];
    }
    // Subnode removals are automatically performed
    [context completeTransition:finished];
  }];
}

/*
 * Hook for subclasses to clean up nodes after the transition happened. Furthermore this can be used from subclasses
 * to manually perform deletions.
 */
- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context
{
  [_pendingLayoutTransition applySubnodeRemovals];
}

#pragma mark _ASTransitionContextCompletionDelegate

/*
 * After completeTransition: is called on the ASContextTransitioning object in animateLayoutTransition: this
 * delegate method will be called that start the completion process of the 
 */
- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete
{
  [self didCompleteLayoutTransition:context];
  _pendingLayoutTransitionContext = nil;

  [self _pendingLayoutTransitionDidComplete];
}

#pragma mark - Layout

/*
 * Completes the pending layout transition immediately without going through the the Layout Transition Animation API
 */
- (void)_completePendingLayoutTransition
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_pendingLayoutTransition) {
    [self setCalculatedDisplayNodeLayout:_pendingLayoutTransition.pendingLayout];
    [self _completeLayoutTransition:_pendingLayoutTransition];
  }
  [self _pendingLayoutTransitionDidComplete];
}

/*
 * Can be directly called to commit the given layout transition immediately to complete without calling through to the
 * Layout Transition Animation API
 */
- (void)_completeLayoutTransition:(ASLayoutTransition *)layoutTransition
{
  // Layout transition is not supported for nodes that are not have automatic subnode management enabled
  if (layoutTransition == nil || self.automaticallyManagesSubnodes == NO) {
    return;
  }

  // Trampoline to the main thread if necessary
  if (ASDisplayNodeThreadIsMain() || layoutTransition.isSynchronous == NO) {
    [layoutTransition commitTransition];
  } else {
    // Subnode insertions and removals need to happen always on the main thread if at least one subnode is already loaded
    ASPerformBlockOnMainThread(^{
      [layoutTransition commitTransition];
    });
  }
}

- (void)_pendingLayoutTransitionDidComplete
{
  ASDN::MutexLocker l(__instanceLock__);
  
  // Subclass hook
  [self calculatedLayoutDidChange];

  // We generate placeholders at measureWithSizeRange: time so that a node is guaranteed to have a placeholder ready to go.
  // This is also because measurement is usually asynchronous, but placeholders need to be set up synchronously.
  // First measurement is guaranteed to be before the node is onscreen, so we can create the image async. but still have it appear sync.
  if (_placeholderEnabled && [self _displaysAsynchronously] && self.contents == nil) {
    
    // Zero-sized nodes do not require a placeholder.
    ASLayout *layout = _calculatedDisplayNodeLayout->layout;
    CGSize layoutSize = (layout ? layout.size : CGSizeZero);
    if (CGSizeEqualToSize(layoutSize, CGSizeZero)) {
      return;
    }

    if (!_placeholderImage) {
      _placeholderImage = [self placeholderImage];
    }
  }
  
  // Cleanup pending layout transition
  _pendingLayoutTransition = nil;
}

- (void)calculatedLayoutDidChange
{
  // subclass override
}

- (void)setMeasurementOptions:(ASDisplayNodePerformanceMeasurementOptions)measurementOptions
{
  ASDN::MutexLocker l(__instanceLock__);
  _measurementOptions = measurementOptions;
}

- (ASDisplayNodePerformanceMeasurementOptions)measurementOptions
{
  ASDN::MutexLocker l(__instanceLock__);
  return _measurementOptions;
}

- (ASDisplayNodePerformanceMeasurements)performanceMeasurements
{
  ASDN::MutexLocker l(__instanceLock__);
  ASDisplayNodePerformanceMeasurements measurements = { .layoutSpecNumberOfPasses = -1, .layoutSpecTotalTime = NAN, .layoutComputationNumberOfPasses = -1, .layoutComputationTotalTime = NAN };
  if (_measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec) {
    measurements.layoutSpecNumberOfPasses = _layoutSpecNumberOfPasses;
    measurements.layoutSpecTotalTime = _layoutSpecTotalTime;
  }
  if (_measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutComputation) {
    measurements.layoutComputationNumberOfPasses = _layoutComputationNumberOfPasses;
    measurements.layoutComputationTotalTime = _layoutComputationTotalTime;
  }
  return measurements;
}

#pragma mark - Asynchronous display

- (BOOL)displaysAsynchronously
{
  ASDN::MutexLocker l(__instanceLock__);
  return [self _displaysAsynchronously];
}

/**
 * Core implementation of -displaysAsynchronously.
 * Must be called with __instanceLock__ held.
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

  ASDN::MutexLocker l(__instanceLock__);

  if (_flags.displaysAsynchronously == displaysAsynchronously)
    return;

  _flags.displaysAsynchronously = displaysAsynchronously;

  self.asyncLayer.displaysAsynchronously = displaysAsynchronously;
}

- (BOOL)shouldRasterizeDescendants
{
  ASDN::MutexLocker l(__instanceLock__);
  ASDisplayNodeAssert(!((_hierarchyState & ASHierarchyStateRasterized) && _flags.shouldRasterizeDescendants),
                      @"Subnode of a rasterized node should not have redundant shouldRasterizeDescendants enabled");
  return _flags.shouldRasterizeDescendants;
}

- (void)setShouldRasterizeDescendants:(BOOL)shouldRasterize
{
  ASDisplayNodeAssertThreadAffinity(self);
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_flags.shouldRasterizeDescendants == shouldRasterize)
      return;
    
    _flags.shouldRasterizeDescendants = shouldRasterize;
  }
  
  if (self.isNodeLoaded) {
    // Recursively tear down or build up subnodes.
    // TODO: When disabling rasterization, preserve rasterized backing store as placeholderImage
    // while the newly materialized subtree finishes rendering.  Then destroy placeholderImage to save memory.
    [self recursivelyClearContents];
    
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode *node) {
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
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode *node) {
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
  ASDN::MutexLocker l(__instanceLock__);

  return _contentsScaleForDisplay;
}

- (void)setContentsScaleForDisplay:(CGFloat)contentsScaleForDisplay
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  if (_contentsScaleForDisplay == contentsScaleForDisplay)
    return;

  _contentsScaleForDisplay = contentsScaleForDisplay;
}

- (void)applyPendingViewState
{
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(__instanceLock__);

  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    //Need to unlock before calling setNeedsLayout to avoid deadlocks.
    //MutexUnlocker will re-lock at the end of scope.
    ASDN::MutexUnlocker u(__instanceLock__);
    [self __setNeedsLayout];
  }

  if (self.layerBacked) {
    [_pendingViewState applyToLayer:self.layer];
  } else {
    BOOL specialPropertiesHandling = ASDisplayNodeNeedsSpecialPropertiesHandlingForFlags(_flags);
    [_pendingViewState applyToView:self.view withSpecialPropertiesHandling:specialPropertiesHandling];
  }

  // _ASPendingState objects can add up very quickly when adding
  // many nodes. This is especially an issue in large collection views
  // and table views. This needs to be weighed against the cost of
  // reallocing a _ASPendingState. So in range managed nodes we
  // delete the pending state, otherwise we just clear it.
  if (ASHierarchyStateIncludesRangeManaged(_hierarchyState)) {
    _pendingViewState = nil;
  } else {
    [_pendingViewState clearChanges];
  }
}

- (void)displayImmediately
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.synchronous, @"this method is designed for asynchronous mode only");

  [[self asyncLayer] displayImmediately];
}

- (void)recursivelyDisplayImmediately
{
  ASDN::MutexLocker l(__instanceLock__);
  
  for (ASDisplayNode *child in _subnodes) {
    [child recursivelyDisplayImmediately];
  }
  [self displayImmediately];
}

//Calling this with the lock held can lead to deadlocks. Always call *unlocked*
- (void)__setNeedsLayout
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  __instanceLock__.lock();
  
  if (_calculatedDisplayNodeLayout->layout == nil) {
    // Can't proceed without a layout as no constrained size would be available. If not layout exists at this moment
    // no measurement pass did happen just bail out for now
    __instanceLock__.unlock();
    return;
  }
    
  [self invalidateCalculatedLayout];
  
  if (_supernode) {
    ASDisplayNode *supernode = _supernode;
    __instanceLock__.unlock();
    // Cause supernode's layout to be invalidated
    // We need to release the lock to prevent a deadlock
    [supernode setNeedsLayout];
    return;
  }
  
  // This is the root node. Trigger a full measurement pass on *current* thread. Old constrained size is re-used.
  [self layoutThatFits:_calculatedDisplayNodeLayout->constrainedSize];
  
  CGRect oldBounds = self.bounds;
  CGSize oldSize = oldBounds.size;
  CGSize newSize = _calculatedDisplayNodeLayout->layout.size;
  
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
  
  __instanceLock__.unlock();
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
  ASDN::MutexLocker l(__instanceLock__);
  CGRect bounds = self.bounds;

  [self measureNodeWithBoundsIfNecessary:bounds];

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

- (void)measureNodeWithBoundsIfNecessary:(CGRect)bounds
{
  BOOL supportsRangeManagedInterfaceState = NO;
  BOOL hasDirtyLayout = NO;
  CGSize calculatedLayoutSize = CGSizeZero;
  {
    ASDN::MutexLocker l(__instanceLock__);
    supportsRangeManagedInterfaceState = [self supportsRangeManagedInterfaceState];
    hasDirtyLayout = _calculatedDisplayNodeLayout->isDirty();
    calculatedLayoutSize = _calculatedDisplayNodeLayout->layout.size;
  }
    
  // Check if it's a subnode in a layout transition. In this case no measurement is needed as it's part of
  // the layout transition
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    ASLayoutElementContext context =  ASLayoutElementGetCurrentContext();
    if (ASLayoutElementContextIsNull(context) || _pendingTransitionID != context.transitionID) {
      return;
    }
  }
  
  // If no measure pass happened or the bounds changed between layout passes we manually trigger a measurement pass
  // for the node using a size range equal to whatever bounds were provided to the node
  if (supportsRangeManagedInterfaceState == NO && (hasDirtyLayout || CGSizeEqualToSize(calculatedLayoutSize, bounds.size) == NO)) {
    if (CGRectEqualToRect(bounds, CGRectZero)) {
      LOG(@"Warning: No size given for node before node was trying to layout itself: %@. Please provide a frame for the node.", self);
    } else {
      [self layoutThatFits:ASSizeRangeMake(bounds.size)];
    }
  }
}

- (void)layoutDidFinish
{
  // Hook for subclasses
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

- (void)willDisplayAsyncLayer:(_ASDisplayLayer *)layer asynchronously:(BOOL)asynchronously
{
  // Subclass hook.
  [self displayWillStart];
  [self displayWillStartAsynchronously:asynchronously];
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
  return (id)kCFNull;
}

#pragma mark - Managing the Node Hierarchy

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
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually add subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _addSubnode:subnode];
}

- (void)_addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  ASDisplayNode *oldParent = subnode.supernode;
  if (!subnode || subnode == self || oldParent == self) {
    return;
  }

  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  BOOL isMovingEquivalentParents = disableNotificationsForMovingBetweenParents(oldParent, self);
  if (isMovingEquivalentParents) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  [subnode _removeFromSupernode];

  if (!_subnodes) {
    _subnodes = [[NSMutableArray alloc] init];
  }

  ASDisplayNodeLogEvent(self, @"%@ %@", NSStringFromSelector(_cmd), subnode);
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
 You must hold __instanceLock__ to call this.

 @param subnode       The subnode to insert
 @param subnodeIndex  The index in _subnodes to insert it
 @param viewSublayerIndex The index in layer.sublayers (not view.subviews) at which to insert the view (use if we can use the view API) otherwise pass NSNotFound
 @param sublayerIndex The index in layer.sublayers at which to insert the layer (use if either parent or subnode is layer-backed) otherwise pass NSNotFound
 @param oldSubnode Remove this subnode before inserting; ok to be nil if no removal is desired
 */
- (void)_insertSubnode:(ASDisplayNode *)subnode atSubnodeIndex:(NSInteger)subnodeIndex sublayerIndex:(NSInteger)sublayerIndex andRemoveSubnode:(ASDisplayNode *)oldSubnode
{
  if (subnodeIndex == NSNotFound) {
    return;
  }
  
  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  if (!subnode) {
    return;
  }

  ASDisplayNode *oldParent = [subnode _deallocSafeSupernode];
  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  BOOL isMovingEquivalentParents = disableNotificationsForMovingBetweenParents(oldParent, self);
  if (isMovingEquivalentParents) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  
  [subnode _removeFromSupernode];
  [oldSubnode _removeFromSupernode];
  
  if (!_subnodes)
    _subnodes = [[NSMutableArray alloc] init];
  ASDisplayNodeLogEvent(self, @"%@: %@", NSStringFromSelector(_cmd), subnode);
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
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually replace old node with replacement node to node with automaticallyManagesSubnodes=YES. Old Node: %@, replacement node: %@", oldSubnode, replacementSubnode);
  [self _replaceSubnode:oldSubnode withSubnode:replacementSubnode];
}

- (void)_replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

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
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode belowSubnode:below];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  if (!subnode) {
    return;
  }

  ASDisplayNodeAssert([below _deallocSafeSupernode] == self, @"Node to insert below must be a subnode");
  if ([below _deallocSafeSupernode] != self) {
    return;
  }

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
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode aboveSubnode:above];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
  if (!subnode) {
    return;
  }

  ASDisplayNodeAssert([above _deallocSafeSupernode] == self, @"Node to insert above must be a subnode");
  if ([above _deallocSafeSupernode] != self) {
    return;
  }

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
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode atIndex:idx];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  if (idx > _subnodes.count || idx < 0) {
    ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %zd. Count is %zd", idx, _subnodes.count);
    return;
  }

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Attempt to insert a nil subnode into node %@", self);
    return;
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
  ASDN::MutexLocker l(__instanceLock__);

  // Don't call self.supernode here because that will retain/autorelease the supernode.  This method -_removeSupernode: is often called while tearing down a node hierarchy, and the supernode in question might be in the middle of its -dealloc.  The supernode is never messaged, only compared by value, so this is safe.
  // The particular issue that triggers this edge case is when a node calls -removeFromSupernode on a subnode from within its own -dealloc method.
  if (!subnode || [subnode _deallocSafeSupernode] != self) {
    return;
  }

  ASDisplayNodeLogEvent(self, @"%@: %@", NSStringFromSelector(_cmd), subnode);
  [_subnodes removeObjectIdenticalTo:subnode];

  [subnode __setSupernode:nil];
}

- (void)removeFromSupernode
{
  //ASDisplayNodeAssert(self.supernode.automaticallyManagesSubnodes == NO, @"Attempt to manually remove subnode from node with automaticallyManagesSubnodes=YES. Node: %@", self);
    
  [self _removeFromSupernode];
}

// NOTE: You must not called this method while holding the receiver's property lock. This may cause deadlocks.
- (void)_removeFromSupernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  __instanceLock__.lock();
    __weak ASDisplayNode *supernode = _supernode;
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
    BOOL layerBacked = _flags.layerBacked;
    BOOL isNodeLoaded = (layer != nil || view != nil);
  __instanceLock__.unlock();

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
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.visibilityNotificationsDisabled > 0;
}

- (BOOL)__selfOrParentHasVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(__instanceLock__);
  return (_hierarchyState & ASHierarchyStateTransitioningSupernodes);
}

- (void)__incrementVisibilityNotificationsDisabled
{
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);
  
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
  ASDN::MutexLocker l(__instanceLock__);
  
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
  ASDN::MutexLocker l(__instanceLock__);
  return [_subnodes copy];
}

- (ASDisplayNode *)supernode
{
  ASDN::MutexLocker l(__instanceLock__);
  return _supernode;
}

// This is a thread-method to return the supernode without causing it to be retained autoreleased.  See -_removeSubnode: for details.
- (ASDisplayNode *)_deallocSafeSupernode
{
  ASDN::MutexLocker l(__instanceLock__);
  return _supernode;
}

- (void)__setSupernode:(ASDisplayNode *)newSupernode
{
  BOOL supernodeDidChange = NO;
  ASDisplayNode *oldSupernode = nil;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_supernode != newSupernode) {
      oldSupernode = _supernode;  // Access supernode properties outside of lock to avoid remote chance of deadlock,
                                  // in case supernode implementation must access one of our properties.
      _supernode = newSupernode;
      supernodeDidChange = YES;
    }
  }
  
  if (supernodeDidChange) {
    ASDisplayNodeLogEvent(self, @"supernodeDidChange: %@, oldValue = %@", ASObjectDescriptionMakeTiny(newSupernode), ASObjectDescriptionMakeTiny(oldSupernode));
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
      
      // If a node was added to a supernode, the supernode could be in a layout pending state. All of the hierarchy state
      // properties related to the transition need to be copied over as well as propagated down the subtree.
      // This is especially important as with automatic subnode management, adding subnodes can happen while a transition
      // is in fly
      if (ASHierarchyStateIncludesLayoutPending(stateToEnterOrExit)) {
        int32_t pendingTransitionId = newSupernode.pendingTransitionID;
        if (pendingTransitionId != ASLayoutElementContextInvalidTransitionID) {
          {
            ASDN::MutexLocker l(__instanceLock__);
            _pendingTransitionID = pendingTransitionId;
            
            // Propagate down the new pending transition id
            ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
              node.pendingTransitionID = _pendingTransitionID;
            });
          }
        }
      }
      
      // Now that we have a supernode, propagate its traits to self.
      ASEnvironmentStatePropagateDown(self, [newSupernode environmentTraitCollection]);
    } else {
      // If a node will be removed from the supernode it should go out from the layout pending state to remove all
      // layout pending state related properties on the node
      stateToEnterOrExit |= ASHierarchyStateLayoutPending;
      
      [self exitHierarchyState:stateToEnterOrExit];
    }
  }
}

// Track that a node will be displayed as part of the current node hierarchy.
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeWillDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  if (!_pendingDisplayNodes) {
    _pendingDisplayNodes = [[ASWeakSet alloc] init];
  }

  [_pendingDisplayNodes addObject:node];
}

// Notify that a node that was pending display finished
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeDidDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  [_pendingDisplayNodes removeObject:node];

  if (_pendingDisplayNodes.isEmpty) {
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

// Helper method to determine if it's safe to call setNeedsDisplay on a layer without throwing away the content.
// For details look at the comment on the canCallSetNeedsDisplayOfLayer flag
- (BOOL)__canCallSetNeedsDisplayOfLayer
{
  return _flags.canCallSetNeedsDisplayOfLayer;
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
  
  if (node.isSynchronous && [node __canCallSetNeedsDisplayOfLayer]) {
    // Layers for UIKit components that are wrapped within a node needs to be set to be displayed as the contents of
    // the layer get's cleared and would not be recreated otherwise.
    // We do not call this for _ASDisplayLayer as an optimization.
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
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, ASLayoutElementSizeResolve(self.style.size, parentSize));
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDN::MutexLocker l(__instanceLock__);
  if ((_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) || _layoutSpecBlock != NULL) {
    BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;
    if (measureLayoutSpec) {
      _layoutSpecNumberOfPasses++;
    }

    ASLayoutSpec *layoutSpec = ({
      ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      [self layoutSpecThatFits:constrainedSize];
    });

    ASDisplayNodeAssert(layoutSpec.isMutable, @"Node %@ returned layout spec %@ that has already been used. Layout specs should always be regenerated.", self, layoutSpec);

    layoutSpec.parent = self; // This causes upward propogation of any non-default layoutElement values.
    
    // manually propagate the trait collection here so that any layoutSpec children of layoutSpec will get a traitCollection
    {
      ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      ASEnvironmentStatePropagateDown(layoutSpec, self.environmentTraitCollection);
    }
    
    layoutSpec.isMutable = NO;
    BOOL measureLayoutComputation = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutComputation;
    if (measureLayoutComputation) {
      _layoutComputationNumberOfPasses++;
    }

    ASLayout *layout = ({
      ASDN::SumScopeTimer t(_layoutComputationTotalTime, measureLayoutComputation);
      [layoutSpec layoutThatFits:constrainedSize];
    });

    ASDisplayNodeAssertNotNil(layout, @"[ASLayoutSpec measureWithSizeRange:] should never return nil! %@, %@", self, layoutSpec);
      
    // Make sure layoutElementObject of the root layout is `self`, so that the flattened layout will be structurally correct.
    BOOL isFinalLayoutElement = (layout.layoutElement != self);
    if (isFinalLayoutElement) {
      layout.position = CGPointZero;
      layout = [ASLayout layoutWithLayoutElement:self size:layout.size sublayouts:@[layout]];
    }
    ASDisplayNodeLogEvent(self, @"computedLayout: %@", layout);
    return [layout filteredNodeLayoutTree];
  } else {
    CGSize size = [self calculateSizeThatFits:constrainedSize.max];
    ASDisplayNodeLogEvent(self, @"calculatedSize: %@", NSStringFromCGSize(size));
    return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:nil];
  }
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  return CGSizeZero;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDN::MutexLocker l(__instanceLock__);
  
  if (_layoutSpecBlock != NULL) {
    return _layoutSpecBlock(self, constrainedSize);
  }
  
  ASDisplayNodeAssert(NO, @"-[ASDisplayNode layoutSpecThatFits:] should never return an empty value. One way this is caused is by calling -[super layoutSpecThatFits:] which is not currently supported.");
  return [[ASLayoutSpec alloc] init];
}

- (void)setLayoutSpecBlock:(ASLayoutSpecBlock)layoutSpecBlock
{
  // For now there should never be a overwrite of layoutSpecThatFits: and a layoutSpecThatFitsBlock: be provided
  ASDisplayNodeAssert(!(_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits), @"Overwriting layoutSpecThatFits: and providing a layoutSpecBlock block is currently not supported");

  ASDN::MutexLocker l(__instanceLock__);
  _layoutSpecBlock = [layoutSpecBlock copy];
}

- (ASLayoutSpecBlock)layoutSpecBlock
{
  ASDN::MutexLocker l(__instanceLock__);
  return _layoutSpecBlock;
}

- (ASLayout *)calculatedLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  return _calculatedDisplayNodeLayout->layout;
}

- (void)setCalculatedDisplayNodeLayout:(std::shared_ptr<ASDisplayNodeLayout>)displayNodeLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  
  ASDisplayNodeAssertTrue(displayNodeLayout->layout.layoutElement == self);
  ASDisplayNodeAssertTrue(displayNodeLayout->layout.size.width >= 0.0);
  ASDisplayNodeAssertTrue(displayNodeLayout->layout.size.height >= 0.0);
  
  _calculatedDisplayNodeLayout = displayNodeLayout;
}

- (CGSize)calculatedSize
{
  ASDN::MutexLocker l(__instanceLock__);
  return _calculatedDisplayNodeLayout->layout.size;
}

- (ASSizeRange)constrainedSizeForCalculatedLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  return _calculatedDisplayNodeLayout->constrainedSize;
}

- (void)setPendingTransitionID:(int32_t)pendingTransitionID
{
  ASDN::MutexLocker l(__instanceLock__);
  ASDisplayNodeAssertTrue(_pendingTransitionID < pendingTransitionID);
  _pendingTransitionID = pendingTransitionID;
}
  
- (int32_t)pendingTransitionID
{
  ASDN::MutexLocker l(__instanceLock__);
  return _pendingTransitionID;
}

- (CGRect)threadSafeBounds
{
  ASDN::MutexLocker l(__instanceLock__);
  return _threadSafeBounds;
}

- (void)setThreadSafeBounds:(CGRect)newBounds
{
  ASDN::MutexLocker l(__instanceLock__);
  _threadSafeBounds = newBounds;
}

- (UIImage *)placeholderImage
{
  return nil;
}

- (void)invalidateCalculatedLayout
{
  ASDN::MutexLocker l(__instanceLock__);

  // This will cause the next call to -layoutThatFits:parentSize: to compute a new layout instead of returning
  // the cached layout in case the constrained or parent size did not change
  _calculatedDisplayNodeLayout->invalidate();
}

- (void)__didLoad
{
  ASDN::MutexLocker l(__instanceLock__);
  
  ASDisplayNodeLogEvent(self, @"didLoad");
  for (ASDisplayNodeDidLoadBlock block in _onDidLoadBlocks) {
    block(self);
  }
  _onDidLoadBlocks = nil;
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
        ASDN::MutexLocker l(__instanceLock__);
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
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
    [node clearContents];
  });
}

- (void)fetchData
{
  // subclass override
}

- (void)setNeedsDataFetch
{
  if (self.isInPreloadState) {
    [self recursivelyFetchData];
  }
}

- (void)recursivelyFetchData
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
    [node fetchData];
  });
}

- (void)clearFetchedData
{
  // subclass override
}

- (void)recursivelyClearFetchedData
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
    [node clearFetchedData];
  });
}

- (void)didEnterVisibleState
{
  // subclass override
}

- (void)didExitVisibleState
{
  // subclass override
}

- (void)didEnterDisplayState
{
  // subclass override
}

- (void)didExitDisplayState
{
  // subclass override
}

- (void)didEnterPreloadState
{
  [self fetchData];
}

- (void)didExitPreloadState
{
  if ([self supportsRangeManagedInterfaceState]) {
    [self clearFetchedData];
  }
}

/**
 * We currently only set interface state on nodes in table/collection views. For other nodes, if they are
 * in the hierarchy we enable all ASInterfaceState types with `ASInterfaceStateInHierarchy`, otherwise `None`.
 */
- (BOOL)supportsRangeManagedInterfaceState
{
  return ASHierarchyStateIncludesRangeManaged(_hierarchyState);
}

- (BOOL)isVisible
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesVisible(_interfaceState);
}

- (BOOL)isInDisplayState
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesDisplay(_interfaceState);
}

- (BOOL)isInPreloadState
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesPreload(_interfaceState);
}

- (ASInterfaceState)interfaceState
{
  ASDN::MutexLocker l(__instanceLock__);
  return _interfaceState;
}

- (void)setInterfaceState:(ASInterfaceState)newState
{
  //This method is currently called on the main thread. The assert has been added here because all of the
  //did(Enter|Exit)(Display|Visible|Preload)State methods currently guarantee calling on main.
  ASDisplayNodeAssertMainThread();
  // It should never be possible for a node to be visible but not be allowed / expected to display.
  ASDisplayNodeAssertFalse(ASInterfaceStateIncludesVisible(newState) && !ASInterfaceStateIncludesDisplay(newState));
  ASInterfaceState oldState = ASInterfaceStateNone;
  {
    ASDN::MutexLocker l(__instanceLock__);
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
  BOOL nowPreload = ASInterfaceStateIncludesPreload(newState);
  BOOL wasPreload = ASInterfaceStateIncludesPreload(oldState);
  
  if (nowPreload != wasPreload) {
    if (nowPreload) {
      ASDisplayNodeLogEvent(self, @"didEnterPreloadState: %@", NSStringFromASInterfaceState(newState));
      [self didEnterPreloadState];
    } else {
      ASDisplayNodeLogEvent(self, @"didExitPreloadState: %@", NSStringFromASInterfaceState(newState));
      [self didExitPreloadState];
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
          ASDN::MutexLocker l(__instanceLock__);
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
              ASDN::MutexLocker l(__instanceLock__);
              if (ASInterfaceStateIncludesDisplay(_interfaceState) == NO) {
                [self clearContents];
              }
            });
          }
        }
      }
    }
    
    if (nowDisplay) {
      ASDisplayNodeLogEvent(self, @"didEnterDisplayState: %@", NSStringFromASInterfaceState(newState));
      [self didEnterDisplayState];
    } else {
      ASDisplayNodeLogEvent(self, @"didExitDisplayState: %@", NSStringFromASInterfaceState(newState));
      [self didExitDisplayState];
    }
  }

  // Became visible or invisible.  When range-managed, this represents literal visibility - at least one pixel
  // is onscreen.  If not range-managed, we can't guarantee more than the node being present in an onscreen window.
  BOOL nowVisible = ASInterfaceStateIncludesVisible(newState);
  BOOL wasVisible = ASInterfaceStateIncludesVisible(oldState);

  if (nowVisible != wasVisible) {
    if (nowVisible) {
      ASDisplayNodeLogEvent(self, @"didEnterVisibleState: %@", NSStringFromASInterfaceState(newState));
      [self didEnterVisibleState];
    } else {
      ASDisplayNodeLogEvent(self, @"didExitVisibleState: %@", NSStringFromASInterfaceState(newState));
      [self didExitVisibleState];
    }
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
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    node.interfaceState |= interfaceState;
  });
}

- (void)exitInterfaceState:(ASInterfaceState)interfaceState
{
  if (interfaceState == ASInterfaceStateNone) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodeLogEvent(self, @"%@ %@", NSStringFromSelector(_cmd), NSStringFromASInterfaceState(interfaceState));
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    node.interfaceState &= (~interfaceState);
  });
}

- (void)recursivelySetInterfaceState:(ASInterfaceState)newInterfaceState
{
  // Instead of each node in the recursion assuming it needs to schedule itself for display,
  // setInterfaceState: skips this when handling range-managed nodes (our whole subtree has this set).
  // If our range manager intends for us to be displayed right now, and didn't before, get started!
  BOOL shouldScheduleDisplay = [self supportsRangeManagedInterfaceState] && [self shouldScheduleDisplayWithNewInterfaceState:newInterfaceState];
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
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
  ASDN::MutexLocker l(__instanceLock__);
  return _hierarchyState;
}

- (void)setHierarchyState:(ASHierarchyState)newState
{
  ASHierarchyState oldState = ASHierarchyStateNormal;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_hierarchyState == newState) {
      return;
    }
    oldState = _hierarchyState;
    _hierarchyState = newState;
  }
  
  // Entered rasterization state.
  if (newState & ASHierarchyStateRasterized) {
    ASDisplayNodeAssert(_flags.synchronous == NO, @"Node created using -initWithViewBlock:/-initWithLayerBlock: cannot be added to subtree of node with shouldRasterizeDescendants=YES. Node: %@", self);
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
        ASDN::MutexLocker l(__instanceLock__);
        _pendingTransitionID = ASLayoutElementContextInvalidTransitionID;
        _pendingLayoutTransition = nil;
      }
    }
  }

  ASDisplayNodeLogEvent(self, @"setHierarchyState: oldState = %@, newState = %@", NSStringFromASHierarchyState(oldState), NSStringFromASHierarchyState(newState));
}

- (void)enterHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  
  ASDisplayNodePerformBlockOnEveryNode(nil, self, NO, ^(ASDisplayNode *node) {
    node.hierarchyState |= hierarchyState;
  });
}

- (void)exitHierarchyState:(ASHierarchyState)hierarchyState
{
  if (hierarchyState == ASHierarchyStateNormal) {
    return; // This method is a no-op with a 0-bitfield argument, so don't bother recursing.
  }
  ASDisplayNodePerformBlockOnEveryNode(nil, self, NO, ^(ASDisplayNode *node) {
    node.hierarchyState &= (~hierarchyState);
  });
}

- (void)layout
{
  ASDisplayNodeAssertMainThread();

  if (_calculatedDisplayNodeLayout->isDirty()) {
    return;
  }
  
  [self __layoutSublayouts];
}

- (void)__layoutSublayouts
{
  for (ASLayout *subnodeLayout in _calculatedDisplayNodeLayout->layout.sublayouts) {
    ((ASDisplayNode *)subnodeLayout.layoutElement).frame = subnodeLayout.frame;
  }
}

#pragma mark - Display

- (void)displayWillStart {}
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  [self displayWillStart]; // Subclass override
  ASDisplayNodeAssertMainThread();

  ASDisplayNodeLogEvent(self, @"displayWillStart");
  // in case current node takes longer to display than it's subnodes, treat it as a dependent node
  [self _pendingNodeWillDisplay:self];
  
  [_supernode subnodeDisplayWillStart:self];
}

- (void)displayDidFinish
{
  ASDisplayNodeAssertMainThread();
  
  ASDisplayNodeLogEvent(self, @"displayDidFinish");
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
  ASDN::MutexLocker l(__instanceLock__);
  if (contentsScale != self.contentsScaleForDisplay) {
    self.contentsScaleForDisplay = contentsScale;
    [self setNeedsDisplay];
  }
}

- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
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
  ASDN::MutexLocker l(__instanceLock__);
  _hitTestSlop = hitTestSlop;
}

- (UIEdgeInsets)hitTestSlop
{
  ASDN::MutexLocker l(__instanceLock__);
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
  ASDN::MutexLocker l(__instanceLock__);

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
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.displaySuspended;
}

- (void)setDisplaySuspended:(BOOL)flag
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.synchronous)
    return;

  ASDN::MutexLocker l(__instanceLock__);

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
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.shouldAnimateSizeChanges;
}

- (void)setShouldAnimateSizeChanges:(BOOL)shouldAnimateSizeChanges
{
  ASDN::MutexLocker l(__instanceLock__);
  _flags.shouldAnimateSizeChanges = shouldAnimateSizeChanges;
}

static const char *ASDisplayNodeDrawingPriorityKey = "ASDrawingPriority";

- (void)setDrawingPriority:(NSInteger)drawingPriority
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);
  if (drawingPriority == ASDefaultDrawingPriority) {
    _flags.hasCustomDrawingPriority = NO;
    objc_setAssociatedObject(self, ASDisplayNodeDrawingPriorityKey, nil, OBJC_ASSOCIATION_ASSIGN);
  } else {
    _flags.hasCustomDrawingPriority = YES;
    objc_setAssociatedObject(self, ASDisplayNodeDrawingPriorityKey, @(drawingPriority), OBJC_ASSOCIATION_RETAIN);
  }
}

- (NSInteger)drawingPriority
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);
  if (!_flags.hasCustomDrawingPriority)
    return ASDefaultDrawingPriority;
  else
    return [objc_getAssociatedObject(self, ASDisplayNodeDrawingPriorityKey) integerValue];
}

- (BOOL)isInHierarchy
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.isInHierarchy;
}

- (void)setInHierarchy:(BOOL)inHierarchy
{
  ASDN::MutexLocker l(__instanceLock__);
  _flags.isInHierarchy = inHierarchy;
}

- (id<ASLayoutElement>)finalLayoutElement
{
  return self;
}

#pragma mark Debugging (Private)

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  if (self.name.length > 0) {
    [result addObject:@{ @"name" : ASStringWithQuotesIfMultiword(self.name) }];
  }
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  
  if (self.name.length > 0) {
    [result addObject:@{ @"name" : ASStringWithQuotesIfMultiword(self.name)}];
  }
  
  CGRect windowFrame = [self _frameInWindow];
  if (CGRectIsNull(windowFrame) == NO) {
    [result addObject:@{ @"frameInWindow" : [NSValue valueWithCGRect:windowFrame] }];
  }
  
  if (_view != nil) {
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_view.frame] }];
  } else if (_layer != nil) {
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_layer.frame] }];
  } else if (_pendingViewState != nil) {
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_pendingViewState.frame] }];
  }
  
  // Check supernode so that if we are cell node we don't find self.
  ASCellNode *cellNode = ASDisplayNodeFindFirstSupernodeOfClass([self _deallocSafeSupernode], [ASCellNode class]);
  if (cellNode != nil) {
    [result addObject:@{ @"cellNode" : ASObjectDescriptionMakeTiny(cellNode) }];
  }
  
  [result addObject:@{ @"interfaceState" : NSStringFromASInterfaceState(self.interfaceState)} ];
  
  if (_view != nil) {
    [result addObject:@{ @"view" : ASObjectDescriptionMakeTiny(_view) }];
  } else if (_layer != nil) {
    [result addObject:@{ @"layer" : ASObjectDescriptionMakeTiny(_layer) }];
  } else if (_viewClass != nil) {
    [result addObject:@{ @"viewClass" : _viewClass }];
  } else if (_layerClass != nil) {
    [result addObject:@{ @"layerClass" : _layerClass }];
  } else if (_viewBlock != nil) {
    [result addObject:@{ @"viewBlock" : _viewBlock }];
  } else if (_layerBlock != nil) {
    [result addObject:@{ @"layerBlock" : _layerBlock }];
  }
  
  return result;
}

- (NSString *)description
{
  return ASObjectDescriptionMake(self, [self propertiesForDescription]);
}

- (NSString *)debugDescription
{
  return ASObjectDescriptionMake(self, [self propertiesForDebugDescription]);
}

// This should only be called for debugging. It's not thread safe and it doesn't assert.
// NOTE: Returns CGRectNull if the node isn't in a hierarchy.
- (CGRect)_frameInWindow
{
  if (self.isNodeLoaded == NO || self.isInHierarchy == NO) {
    return CGRectNull;
  }

  if (self.layerBacked) {
    CALayer *rootLayer = _layer;
    CALayer *nextLayer = rootLayer;
    while ((nextLayer = rootLayer.superlayer) != nil) {
      rootLayer = nextLayer;
    }

    return [_layer convertRect:self.threadSafeBounds toLayer:rootLayer];
  } else {
    return [_view convertRect:self.threadSafeBounds toView:nil];
  }
}

#pragma mark - NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nullable [_Nonnull])buffer count:(NSUInteger)len
{
  return [self.subnodes countByEnumeratingWithState:state objects:buffer count:len];
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
    ASDisplayNodeLogEvent(self, @"asyncTraitCollectionDidChange: %@", NSStringFromASEnvironmentTraitCollection(environmentTraitCollection));
    [self asyncTraitCollectionDidChange];
  }
}

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(__instanceLock__);
  return [ASTraitCollection traitCollectionWithASEnvironmentTraitCollection:self.environmentTraitCollection];
}

- (void)asyncTraitCollectionDidChange
{
  // Subclass override
}

ASEnvironmentLayoutExtensibilityForwarding

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

#pragma mark - Deprecated

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
}


ASLayoutElementStyleForwarding

- (void)setPreferredFrameSize:(CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(__instanceLock__);

  // Deprecated preferredFrameSize just calls through to set width and height
  self.style.preferredSize = preferredFrameSize;
  [self invalidateCalculatedLayout];
}

- (CGSize)preferredFrameSize
{
  ASDN::MutexLocker l(__instanceLock__);
  
  ASLayoutElementStyle *style = self.style;
  if (style.width.unit == ASDimensionUnitPoints && style.height.unit == ASDimensionUnitPoints) {
    return CGSizeMake(style.width.value, style.height.value);
  }

  return CGSizeZero;
}

@end

@implementation ASDisplayNode (Debugging)

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

#pragma mark - ASLayoutElementAsciiArtProtocol

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
  ASWeakProxy *weakProxy = [ASWeakProxy weakProxyWithTarget:node];
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, weakProxy, OBJC_ASSOCIATION_RETAIN); // Weak reference to avoid cycle, since the node retains the view.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  ASWeakProxy *weakProxy = objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
  return weakProxy.target;
}

@end

@implementation CALayer (ASDisplayNodeInternal)

- (void)setAsyncdisplaykit_node:(ASDisplayNode *)node
{
  ASWeakProxy *weakProxy = [ASWeakProxy weakProxyWithTarget:node];
  objc_setAssociatedObject(self, ASDisplayNodeAssociatedNodeKey, weakProxy, OBJC_ASSOCIATION_RETAIN); // Weak reference to avoid cycle, since the node retains the layer.
}

- (ASDisplayNode *)asyncdisplaykit_node
{
  ASWeakProxy *weakProxy = objc_getAssociatedObject(self, ASDisplayNodeAssociatedNodeKey);
  return weakProxy.target;
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

- (CGSize)measure:(CGSize)constrainedSize
{
  return [self layoutThatFits:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;
}

- (void)cancelLayoutTransitionsInProgress
{
  [self cancelLayoutTransition];
}

- (BOOL)usesImplicitHierarchyManagement
{
  return self.automaticallyManagesSubnodes;
}

- (void)setUsesImplicitHierarchyManagement:(BOOL)enabled
{
  self.automaticallyManagesSubnodes = enabled;
}

@end
