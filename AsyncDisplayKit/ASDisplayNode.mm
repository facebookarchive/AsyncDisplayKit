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
#import "AsyncDisplayKit+Debug.h"

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
#import "ASLayoutSpec+Subclasses.h"
#import "ASLayoutSpec.h"
#import "ASCellNode+Internal.h"
#import "ASWeakProxy.h"
#import "ASLayoutSpecPrivate.h"

#if DEBUG
  #define AS_DEDUPE_LAYOUT_SPEC_TREE 1
#endif

NSInteger const ASDefaultDrawingPriority = ASDefaultTransactionPriority;
NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification = @"ASRenderingEngineDidDisplayScheduledNodes";
NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp = @"ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp";

// Forward declare CALayerDelegate protocol as the iOS 10 SDK moves CALayerDelegate from a formal delegate to a protocol.
// We have to forward declare the protocol as this place otherwise it will not compile compiling with an Base SDK < iOS 10
@protocol CALayerDelegate;

@interface ASDisplayNode () <UIGestureRecognizerDelegate, _ASDisplayLayerDelegate, _ASTransitionContextCompletionDelegate>
{
  BOOL _shouldCacheLayoutSpec;
  ASLayoutSpec *_layoutSpec;
}

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

@synthesize debugName = _debugName;
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
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(fetchData))) {
    overrides |= ASDisplayNodeMethodOverrideFetchData;
  }
  if (ASDisplayNodeSubclassOverridesSelector(c, @selector(clearFetchedData))) {
    overrides |= ASDisplayNodeMethodOverrideClearFetchedData;
  }

  return overrides;
}

  // At most a layoutSpecBlock or one of the three layout methods is overridden
#define __ASDisplayNodeCheckForLayoutMethodOverrides \
    ASDisplayNodeAssert(_layoutSpecBlock != NULL || \
    ((ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateSizeThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(layoutSpecThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateLayoutThatFits:)) ? 1 : 0)) <= 1, \
    @"Subclass %@ must at least provide a layoutSpecBlock or override at most one of the three layout methods: calculateLayoutThatFits:, layoutSpecThatFits:, or calculateSizeThatFits:", NSStringFromClass(self.class))

+ (void)initialize
{
  [super initialize];
  if (self != [ASDisplayNode class]) {
    
    // Subclasses should never override these. Use unused to prevent warnings
    __unused NSString *classString = NSStringFromClass(self);
    
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measure:)), @"Subclass %@ must not override measure: method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange: method. Instead overwrite calculateLayoutThatFits:", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:)), @"Subclass %@ must not override layoutThatFits: method. Instead overwrite calculateLayoutThatFits:.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:parentSize:)), @"Subclass %@ must not override layoutThatFits:parentSize method. Instead overwrite calculateLayoutThatFits:.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearContents)), @"Subclass %@ must not override recursivelyClearContents method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(recursivelyClearPreloadedData)), @"Subclass %@ must not override recursivelyClearFetchedData method.", classString);
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
  // Check if subnodes where modified during the creation of the layout
  if (self == [ASDisplayNode class]) {
    __block IMP originalLayoutSpecThatFitsIMP = ASReplaceMethodWithBlock(self, @selector(_layoutElementThatFits:), ^(ASDisplayNode *_self, ASSizeRange sizeRange) {
      NSArray *oldSubnodes = _self.subnodes;
      ASLayoutSpec *layoutElement = ((ASLayoutSpec *( *)(id, SEL, ASSizeRange))originalLayoutSpecThatFitsIMP)(_self, @selector(_layoutElementThatFits:), sizeRange);
      NSArray *subnodes = _self.subnodes;
      ASDisplayNodeAssert(oldSubnodes.count == subnodes.count, @"Adding or removing nodes in layoutSpecBlock or layoutSpecThatFits: is not allowed and can cause unexpected behavior.");
      for (NSInteger i = 0; i < oldSubnodes.count; i++) {
        ASDisplayNodeAssert(oldSubnodes[i] == subnodes[i], @"Adding or removing nodes in layoutSpecBlock or layoutSpecThatFits: is not allowed and can cause unexpected behavior.");
      }
      return layoutElement;
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
        CFTimeInterval timestamp = CACurrentMediaTime();
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

#if ASEVENTLOG_ENABLE
  _eventLog = [[ASEventLog alloc] initWithObject:self];
#endif
  
  _contentsScaleForDisplay = ASScreenScale();
  
  _environmentState = ASEnvironmentStateMakeDefault();
  
  _calculatedDisplayNodeLayout = std::make_shared<ASDisplayNodeLayout>();
  _pendingDisplayNodeLayout = nullptr;
  
  _defaultLayoutTransitionDuration = 0.2;
  _defaultLayoutTransitionDelay = 0.0;
  _defaultLayoutTransitionOptions = UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionTransitionNone;
  
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
  _flags.isDeallocating = YES;

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

  // Trampoline any UIKit ivars' deallocation to main
  if (ASDisplayNodeThreadIsMain() == NO) {
    [self _scheduleIvarsForMainDeallocation];
  }

  _subnodes = nil;

  // TODO: Remove this? If supernode isn't already nil, this method isn't dealloc-safe anyway.
  [self __setSupernode:nil];
}

- (void)_scheduleIvarsForMainDeallocation
{
  NSValue *ivarsObj = [[self class] _ivarsThatMayNeedMainDeallocation];

  // Unwrap the ivar array
  unsigned int count = 0;
  // Will be unused if assertions are disabled.
  __unused int scanResult = sscanf(ivarsObj.objCType, "[%u^{objc_ivar}]", &count);
  ASDisplayNodeAssert(scanResult == 1, @"Unexpected type in NSValue: %s", ivarsObj.objCType);
  Ivar ivars[count];
  [ivarsObj getValue:ivars];

  for (Ivar ivar : ivars) {
    id value = object_getIvar(self, ivar);
    if (ASClassRequiresMainThreadDeallocation(object_getClass(value))) {
      LOG(@"Trampolining ivar '%s' value %@ for main deallocation.", ivar_getName(ivar), value);
      ASPerformMainThreadDeallocation(value);
    } else {
      LOG(@"Not trampolining ivar '%s' value %@.", ivar_getName(ivar), value);
    }
  }
}

/**
 * Returns an NSValue-wrapped array of all the ivars in this class or its superclasses
 * up through ASDisplayNode, that we expect may need to be deallocated on main.
 * 
 * This method caches its results.
 */
+ (NSValue/*<[Ivar]>*/ * _Nonnull)_ivarsThatMayNeedMainDeallocation
{
  static NSCache<Class, NSValue *> *ivarsCache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ivarsCache = [[NSCache alloc] init];
  });

  NSValue *result = [ivarsCache objectForKey:self];
  if (result != nil) {
    return result;
  }

  // Cache miss.
  unsigned int resultCount = 0;
  static const int kMaxDealloc2MainIvarsPerClassTree = 64;
  Ivar resultIvars[kMaxDealloc2MainIvarsPerClassTree];

  // Get superclass results first.
  Class c = class_getSuperclass(self);
  if (c != [NSObject class]) {
    NSValue *ivarsObj = [c _ivarsThatMayNeedMainDeallocation];
    // Unwrap the ivar array and append it to our working array
    unsigned int count = 0;
    // Will be unused if assertions are disabled.
    __unused int scanResult = sscanf(ivarsObj.objCType, "[%u^{objc_ivar}]", &count);
    ASDisplayNodeAssert(scanResult == 1, @"Unexpected type in NSValue: %s", ivarsObj.objCType);
    ASDisplayNodeCAssert(resultCount + count < kMaxDealloc2MainIvarsPerClassTree, @"More than %d dealloc2main ivars are not supported. Count: %d", kMaxDealloc2MainIvarsPerClassTree, resultCount + count);
    [ivarsObj getValue:resultIvars + resultCount];
    resultCount += count;
  }

  // Now gather ivars from this particular class.
  unsigned int allMyIvarsCount;
  Ivar *allMyIvars = class_copyIvarList(self, &allMyIvarsCount);

  for (NSUInteger i = 0; i < allMyIvarsCount; i++) {
    Ivar ivar = allMyIvars[i];
    const char *type = ivar_getTypeEncoding(ivar);

    if (strcmp(type, @encode(id)) == 0) {
      // If it's `id` we have to include it just in case.
      resultIvars[resultCount] = ivar;
      resultCount += 1;
      LOG(@"Marking ivar '%s' for possible main deallocation due to type id", ivar_getName(ivar));
    } else {
      // If it's an ivar with a static type, check the type.
      Class c = ASGetClassFromType(type);
      if (ASClassRequiresMainThreadDeallocation(c)) {
        resultIvars[resultCount] = ivar;
        resultCount += 1;
        LOG(@"Marking ivar '%s' for main deallocation due to class %@", ivar_getName(ivar), c);
      } else {
        LOG(@"Skipping ivar '%s' for main deallocation.", ivar_getName(ivar));
      }
    }
  }
  free(allMyIvars);

  // Encode the type (array of Ivars) into a string and wrap it in an NSValue
  char arrayType[32];
  snprintf(arrayType, 32, "[%u^{objc_ivar}]", resultCount);
  result = [NSValue valueWithBytes:resultIvars objCType:arrayType];

  [ivarsCache setObject:result forKey:self];
  return result;
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
  if (_flags.synchronous && ([_viewClass isSubclassOfClass:[UIImageView class]] || [_viewClass isSubclassOfClass:[UIActivityIndicatorView class]])) {
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

  if (_flags.isDeallocating) {
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

- (NSString *)debugName
{
  ASDN::MutexLocker l(__instanceLock__);
  return _debugName;
}

- (void)setDebugName:(NSString *)debugName
{
  ASDN::MutexLocker l(__instanceLock__);
  if (!ASObjectIsEqual(_debugName, debugName)) {
    _debugName = [debugName copy];
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

- (void)setNeedsLayoutFromAbove
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  __instanceLock__.lock();

  // Mark the node for layout in the next layout pass
  [self setNeedsLayout];
  
  // Escalate to the root; entire tree must allow adjustments so the layout fits the new child.
  // Much of the layout will be re-used as cached (e.g. other items in an unconstrained stack)
  ASDisplayNode *supernode = _supernode;
  if (supernode) {
    // Threading model requires that we unlock before calling a method on our parent.
    __instanceLock__.unlock();
    [supernode setNeedsLayoutFromAbove];
    return;
  }
  
  // We are the root node and need to re-flow the layout; at least one child needs a new size.
  CGSize boundsSizeForLayout = ASCeilSizeValues(self.bounds.size);

  // Figure out constrainedSize to use
  ASSizeRange constrainedSize = ASSizeRangeMake(boundsSizeForLayout);
  if (_pendingDisplayNodeLayout != nullptr) {
    constrainedSize = _pendingDisplayNodeLayout->constrainedSize;
  } else if (_calculatedDisplayNodeLayout->layout != nil) {
    constrainedSize = _calculatedDisplayNodeLayout->constrainedSize;
  }

  // Perform a measurement pass to get the full tree layout, adapting to the child's new size.
  ASLayout *layout = [self layoutThatFits:constrainedSize];
  
  // Check if the returned layout has a different size than our current bounds.
  if (CGSizeEqualToSize(boundsSizeForLayout, layout.size) == NO) {
    // If so, inform our container we need an update (e.g Table, Collection, ViewController, etc).
    [self _locked_displayNodeDidInvalidateSizeNewSize:layout.size];
  }
  
  __instanceLock__.unlock();
}

- (void)_locked_displayNodeDidInvalidateSizeNewSize:(CGSize)size
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  // The default implementation of display node changes the size of itself to the new size
  CGRect oldBounds = self.bounds;
  CGSize oldSize = oldBounds.size;
  CGSize newSize = size;
  
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
 
  // If one or multiple layout transitions are in flight it still can happen that layout information is requested
  // on other threads. As the pending and calculated layout to be updated in the layout transition in here just a
  // layout calculation wil be performed without side effect
  if ([self _isLayoutTransitionInvalid]) {
    return [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize];
  }

  if (_calculatedDisplayNodeLayout->isValidForConstrainedSizeParentSize(constrainedSize, parentSize)) {
    ASDisplayNodeAssertNotNil(_calculatedDisplayNodeLayout->layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _calculatedDisplayNodeLayout->layout should not be nil! %@", self);
    // Our calculated layout is suitable for this constrainedSize, so keep using it and
    // invalidate any pending layout that has been generated in the past.
    _pendingDisplayNodeLayout = nullptr;
    return _calculatedDisplayNodeLayout->layout ?: [ASLayout layoutWithLayoutElement:self size:{0, 0}];
  }
  
  // Creat a pending display node layout for the layout pass
  _pendingDisplayNodeLayout = std::make_shared<ASDisplayNodeLayout>(
    [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize],
    constrainedSize,
    parentSize
  );
  
  ASDisplayNodeAssertNotNil(_pendingDisplayNodeLayout->layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _pendingDisplayNodeLayout->layout should not be nil! %@", self);
  return _pendingDisplayNodeLayout->layout ?: [ASLayout layoutWithLayoutElement:self size:{0, 0}];
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
  ASDisplayNodeAssertMainThread();

  [self setNeedsLayout];
  
  [self transitionLayoutWithSizeRange:[self _locked_constrainedSizeForLayoutPass]
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
  
  if (constrainedSize.max.width <= 0.0 || constrainedSize.max.height <= 0.0) {
    // Using CGSizeZero for the sizeRange can cause negative values in client layout code.
    // Most likely called transitionLayout: without providing a size, before first layout pass.
    return;
  }
    
  // Check if we are a subnode in a layout transition.
  // In this case no measurement is needed as we're part of the layout transition.
  if ([self _isLayoutTransitionInvalid]) {
    return;
  }
  
  {
    ASDN::MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO, @"Can't start a transition when one of the supernodes is performing one.");
  }
  
  // Every new layout transition has a transition id associated to check in subsequent transitions for cancelling
  int32_t transitionID = [self _startNewTransition];
  
  // Move all subnodes in layout pending state for this transition
  ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
    ASDisplayNodeAssert([node _isTransitionInProgress] == NO, @"Can't start a transition when one of the subnodes is performing one.");
    node.hierarchyState |= ASHierarchyStateLayoutPending;
    node.pendingTransitionID = transitionID;
  });
  
  // Transition block that executes the layout transition
  void (^transitionBlock)(void) = ^{
    if ([self _shouldAbortTransitionWithID:transitionID]) {
      return;
    }
    
    // Perform a full layout creation pass with passed in constrained size to create the new layout for the transition
    ASLayout *newLayout;
    {
      ASDN::MutexLocker l(__instanceLock__);

      BOOL shouldVisualizeLayout = ASHierarchyStateIncludesVisualizeLayout(_hierarchyState);
      ASLayoutElementSetCurrentContext(ASLayoutElementContextMake(transitionID, shouldVisualizeLayout));

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

      // Update calculated layout
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
        
      // Mark transaction as finished
      [self _finishOrCancelTransition];
    });
  };
  
  // Start transition based on flag on current or background thread
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

- (BOOL)_isLayoutTransitionInvalid
{
  ASDN::MutexLocker l(__instanceLock__);
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState)) {
    ASLayoutElementContext context = ASLayoutElementGetCurrentContext();
    if (ASLayoutElementContextIsNull(context) || _pendingTransitionID != context.transitionID) {
      return YES;
    }
  }
  return NO;
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
  if (_placeholderEnabled && !_placeholderImage && [self _displaysAsynchronously]) {
    
    // Zero-sized nodes do not require a placeholder.
    ASLayout *layout = _calculatedDisplayNodeLayout->layout;
    CGSize layoutSize = (layout ? layout.size : CGSizeZero);
    if (layoutSize.width * layoutSize.height <= 0.0) {
      return;
    }
    
    // If we've displayed our contents, we don't need a placeholder.
    // Contents is a thread-affined property and can't be read off main after loading.
    if (self.isNodeLoaded) {
      ASPerformBlockOnMainThread(^{
        if (self.contents == nil) {
          _placeholderImage = [self placeholderImage];
        }
      });
    } else {
      if (self.contents == nil) {
        _placeholderImage = [self placeholderImage];
      }
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
  BOOL rasterizedFromSelfOrAncestor = NO;
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (_flags.shouldRasterizeDescendants == shouldRasterize)
      return;
    
    _flags.shouldRasterizeDescendants = shouldRasterize;
    rasterizedFromSelfOrAncestor = shouldRasterize || ASHierarchyStateIncludesRasterized(_hierarchyState);
  }
  
  if (self.isNodeLoaded) {
    // Recursively tear down or build up subnodes.
    // TODO: When disabling rasterization, preserve rasterized backing store as placeholderImage
    // while the newly materialized subtree finishes rendering.  Then destroy placeholderImage to save memory.
    [self recursivelyClearContents];
    
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode *node) {
      if (rasterizedFromSelfOrAncestor) {
        [node enterHierarchyState:ASHierarchyStateRasterized];
        if (node.isNodeLoaded) {
          [node __unloadNode];
        }
      } else {
        [node exitHierarchyState:ASHierarchyStateRasterized];
        // We can avoid eagerly loading this node. We will load it on-demand as usual.
      }
    });
    if (!rasterizedFromSelfOrAncestor) {
      // If we are not going to rasterize at all, go ahead and set up our view hierarchy.
      [self _addSubnodeViewsAndLayers];
    }
    
    if (ASInterfaceStateIncludesVisible(self.interfaceState)) {
      // TODO: Change this to recursivelyEnsureDisplay - but need a variant that does not skip
      // nodes that have shouldBypassEnsureDisplay set (such as image nodes) so they are rasterized.
      [self recursivelyDisplayImmediately];
    }
  } else {
    ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode *node) {
      if (rasterizedFromSelfOrAncestor) {
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

- (void)invalidateCalculatedLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  
  // This will cause the next layout pass to compute a new layout instead of returning
  // the cached layout in case the constrained or parent size did not change
  _calculatedDisplayNodeLayout->invalidate();
  if (_pendingDisplayNodeLayout != nullptr) {
    _pendingDisplayNodeLayout->invalidate();
  }
}

- (void)__setNeedsLayout
{
  ASDN::MutexLocker l(__instanceLock__);

  [self invalidateCalculatedLayout];
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
  CGRect bounds = _threadSafeBounds;
  
  if (CGRectEqualToRect(bounds, CGRectZero)) {
    // Performing layout on a zero-bounds view often results in frame calculations
    // with negative sizes after applying margins, which will cause
    // measureWithSizeRange: on subnodes to assert.
    LOG(@"Warning: No size given for node before node was trying to layout itself: %@. Please provide a frame for the node.", self);
    return;
  }
  
  // If a current layout transition is in progress there is no need to do a measurement and layout pass in here as
  // this is supposed to happen within the layout transition process
  if ([self _isTransitionInProgress]) {
    return;
  }
    
  // This method will confirm that the layout is up to date (and update if needed).
  // Importantly, it will also APPLY the layout to all of our subnodes if (unless parent is transitioning).
  [self _locked_measureNodeWithBoundsIfNecessary:bounds];
  _pendingDisplayNodeLayout = nullptr;
  
  [self _locked_layoutPlaceholderIfNecessary];
  
  [self layout];
  [self layoutDidFinish];
}

/// Needs to be called with lock held
- (void)_locked_measureNodeWithBoundsIfNecessary:(CGRect)bounds
{
  // Check if we are a subnode in a layout transition.
  // In this case no measurement is needed as it's part of the layout transition
  if ([self _isLayoutTransitionInvalid]) {
    return;
  }
  
  CGSize boundsSizeForLayout = ASCeilSizeValues(bounds.size);
  
  // Prefer _pendingDisplayNodeLayout over _calculatedDisplayNodeLayout (if exists, it's the newest)
  // If there is no _pending, check if _calculated is valid to reuse (avoiding recalculation below).
  if (_pendingDisplayNodeLayout == nullptr) {
    if (_calculatedDisplayNodeLayout->isDirty() == NO
        && (_calculatedDisplayNodeLayout->requestedLayoutFromAbove == YES
            || CGSizeEqualToSize(_calculatedDisplayNodeLayout->layout.size, boundsSizeForLayout))) {
      return;
    }
  }
  
  // _calculatedDisplayNodeLayout is not reusable we need to transition to a new one
  [self cancelLayoutTransition];
  
  BOOL didCreateNewContext = NO;
  BOOL didOverrideExistingContext = NO;
  BOOL shouldVisualizeLayout = ASHierarchyStateIncludesVisualizeLayout(_hierarchyState);
  ASLayoutElementContext context = ASLayoutElementGetCurrentContext();
  if (ASLayoutElementContextIsNull(context)) {
    context = ASLayoutElementContextMake(ASLayoutElementContextDefaultTransitionID, shouldVisualizeLayout);
    ASLayoutElementSetCurrentContext(context);
    didCreateNewContext = YES;
  } else {
    if (context.needsVisualizeNode != shouldVisualizeLayout) {
      context.needsVisualizeNode = shouldVisualizeLayout;
      ASLayoutElementSetCurrentContext(context);
      didOverrideExistingContext = YES;
    }
  }
  
  // Figure out previous and pending layouts for layout transition
  std::shared_ptr<ASDisplayNodeLayout> nextLayout = _pendingDisplayNodeLayout;
  #define layoutSizeDifferentFromBounds !CGSizeEqualToSize(nextLayout->layout.size, boundsSizeForLayout)
  
  // nextLayout was likely created by a call to layoutThatFits:, check if is valid and can be applied.
  // If our bounds size is different than it, or invalid, recalculate.  Use #define to avoid nullptr->
  if (nextLayout == nullptr || nextLayout->isDirty() == YES || layoutSizeDifferentFromBounds) {
    // Use the last known constrainedSize passed from a parent during layout (if never, use bounds).
    ASSizeRange constrainedSize = [self _locked_constrainedSizeForLayoutPass];
    ASLayout *layout = [self calculateLayoutThatFits:constrainedSize
                                    restrictedToSize:self.style.size
                                relativeToParentSize:boundsSizeForLayout];
    
    nextLayout = std::make_shared<ASDisplayNodeLayout>(layout, constrainedSize, boundsSizeForLayout);
  }
  
  if (didCreateNewContext) {
    ASLayoutElementClearCurrentContext();
  } else if (didOverrideExistingContext) {
    context.needsVisualizeNode = !context.needsVisualizeNode;
    ASLayoutElementSetCurrentContext(context);
  }
  
  // If our new layout's desired size for self doesn't match current size, ask our parent to update it.
  // This can occur for either pre-calculated or newly-calculated layouts.
  if (nextLayout->requestedLayoutFromAbove == NO
      && CGSizeEqualToSize(boundsSizeForLayout, nextLayout->layout.size) == NO) {
    // The layout that we have specifies that this node (self) would like to be a different size
    // than it currently is.  Because that size has been computed within the constrainedSize, we
    // expect that calling setNeedsLayoutFromAbove will result in our parent resizing us to this.
    // However, in some cases apps may manually interfere with this (setting a different bounds).
    // In this case, we need to detect that we've already asked to be resized to match this
    // particular ASLayout object, and shouldn't loop asking again unless we have a different ASLayout.
    nextLayout->requestedLayoutFromAbove = YES;
    [self setNeedsLayoutFromAbove];
  }

  // Prepare to transition to nextLayout
  ASDisplayNodeAssertNotNil(nextLayout->layout, @"nextLayout->layout should not be nil! %@", self);
  _pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                        pendingLayout:nextLayout
                                                       previousLayout:_calculatedDisplayNodeLayout];

  // If a parent is currently executing a layout transition, perform our layout application after it.
  if (ASHierarchyStateIncludesLayoutPending(_hierarchyState) == NO) {
    // If no transition, apply our new layout immediately (common case).
    [self _completePendingLayoutTransition];
  }
}

- (ASSizeRange)_locked_constrainedSizeForLayoutPass
{
  // TODO: The logic in -setNeedsLayoutFromAbove seems correct and doesn't use this method.
  // logic seems correct.  For what case does -this method need to do the CGSizeEqual checks?
  // IF WE CAN REMOVE BOUNDS CHECKS HERE, THEN WE CAN ALSO REMOVE "REQUESTED FROM ABOVE" CHECK
  
  CGSize boundsSizeForLayout = ASCeilSizeValues(self.threadSafeBounds.size);
  
  // Checkout if constrained size of pending or calculated display node layout can be used
  if (_pendingDisplayNodeLayout != nullptr
      && (_pendingDisplayNodeLayout->requestedLayoutFromAbove
           || CGSizeEqualToSize(_pendingDisplayNodeLayout->layout.size, boundsSizeForLayout))) {
    // We assume the size from the last returned layoutThatFits: layout was applied so use the pending display node
    // layout constrained size
    return _pendingDisplayNodeLayout->constrainedSize;
  } else if (_calculatedDisplayNodeLayout->layout != nil
             && (_calculatedDisplayNodeLayout->requestedLayoutFromAbove
                 || CGSizeEqualToSize(_calculatedDisplayNodeLayout->layout.size, boundsSizeForLayout))) {
    // We assume the  _calculatedDisplayNodeLayout is still valid and the frame is not different
    return _calculatedDisplayNodeLayout->constrainedSize;
  } else {
    // In this case neither the _pendingDisplayNodeLayout or the _calculatedDisplayNodeLayout constrained size can
    // be reused, so the current bounds is used. This is usual the case if a frame was set manually that differs to
    // the one returned from layoutThatFits: or layoutThatFits: was never called
    return ASSizeRangeMake(boundsSizeForLayout);
  }
}

- (void)_locked_layoutPlaceholderIfNecessary
{
  if ([self _shouldHavePlaceholderLayer]) {
    [self _setupPlaceholderLayerIfNeeded];
  }
  // Update the placeholderLayer size in case the node size has changed since the placeholder was added.
  _placeholderLayer.frame = self.threadSafeBounds;
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

ASDISPLAYNODE_INLINE bool shouldDisableNotificationsForMovingBetweenParents(ASDisplayNode *from, ASDisplayNode *to) {
  if (!from || !to) return NO;
  if (from->_flags.synchronous) return NO;
  if (to->_flags.synchronous) return NO;
  if (from->_flags.isInHierarchy != to->_flags.isInHierarchy) return NO;
  return YES;
}

/// Returns incremented value of i if i is not NSNotFound
ASDISPLAYNODE_INLINE NSInteger incrementIfFound(NSInteger i) {
  return i == NSNotFound ? NSNotFound : i + 1;
}

/// Returns if a node is a member of a rasterized tree
ASDISPLAYNODE_INLINE BOOL canUseViewAPI(ASDisplayNode *node, ASDisplayNode *subnode) {
  return (subnode.isLayerBacked == NO && node.isLayerBacked == NO);
}

/// Returns if node is a member of a rasterized tree
ASDISPLAYNODE_INLINE BOOL nodeIsInRasterizedTree(ASDisplayNode *node) {
  return (node->_flags.shouldRasterizeDescendants || (node->_hierarchyState & ASHierarchyStateRasterized));
}

/*
 * Central private helper method that should eventually be called if submethods add, insert or replace subnodes
 * You must hold __instanceLock__ to call this.
 * This method is called with thread affinity.
 *
 * @param subnode       The subnode to insert
 * @param subnodeIndex  The index in _subnodes to insert it
 * @param viewSublayerIndex The index in layer.sublayers (not view.subviews) at which to insert the view (use if we can use the view API) otherwise pass NSNotFound
 * @param sublayerIndex The index in layer.sublayers at which to insert the layer (use if either parent or subnode is layer-backed) otherwise pass NSNotFound
 * @param oldSubnode Remove this subnode before inserting; ok to be nil if no removal is desired
 */
- (void)_insertSubnode:(ASDisplayNode *)subnode atSubnodeIndex:(NSInteger)subnodeIndex sublayerIndex:(NSInteger)sublayerIndex andRemoveSubnode:(ASDisplayNode *)oldSubnode
{
  if (subnode == nil || subnode == self) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode or self as subnode");
    return;
  }
  
  if (subnodeIndex == NSNotFound) {
    ASDisplayNodeFailAssert(@"Try to insert node on an index that was not found");
    return;
  }
  
  if (subnodeIndex > _subnodes.count || subnodeIndex < 0) {
    ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %zd. Count is %zd", subnodeIndex, _subnodes.count);
    return;
  }
  
  // Disable appearance methods during move between supernodes, but make sure we restore their state after we do our thing
  ASDisplayNode *oldParent = subnode.supernode;
  BOOL disableNotifications = shouldDisableNotificationsForMovingBetweenParents(oldParent, self);
  if (disableNotifications) {
    [subnode __incrementVisibilityNotificationsDisabled];
  }
  
  [subnode _removeFromSupernode];
  [oldSubnode _removeFromSupernode];
  
  if (_subnodes == nil) {
    _subnodes = [[NSMutableArray alloc] init];
  }
    
  [_subnodes insertObject:subnode atIndex:subnodeIndex];
  
  // This call will apply our .hierarchyState to the new subnode.
  // If we are a managed hierarchy, as in ASCellNode trees, it will also apply our .interfaceState.
  [subnode __setSupernode:self];

  // If this subnode will be rasterized, update its hierarchy state & enter hierarchy if needed
  if (nodeIsInRasterizedTree(self)) {
    ASDisplayNodePerformBlockOnEveryNodeBFS(subnode, ^(ASDisplayNode * _Nonnull node) {
      [node enterHierarchyState:ASHierarchyStateRasterized];
      if (node.isNodeLoaded) {
        [node __unloadNode];
      }
    });
    if (_flags.isInHierarchy) {
      [subnode __enterHierarchy];
    }
  } else if (self.nodeLoaded) {
    // If not rasterizing, and node is loaded insert the subview/sublayer now.
    [self _insertSubnodeSubviewOrSublayer:subnode atIndex:sublayerIndex];
  } // Otherwise we will insert subview/sublayer when we get loaded

  ASDisplayNodeAssert(disableNotifications == shouldDisableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (disableNotifications) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }
}

/*
 * Inserts the view or layer of the given node at the given index
 * You must hold __instanceLock__ to call this.
 *
 * @param subnode       The subnode to insert
 * @param idx           The index in _view.subviews or _layer.sublayers at which to insert the subnode.view or
 *                      subnode.layer of the subnode
 */
- (void)_insertSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"_insertSubnodeSubviewOrSublayer:atIndex: should never be called before our own view is created");

  ASDisplayNodeAssert(idx != NSNotFound, @"Try to insert node on an index that was not found");
  if (idx == NSNotFound) {
    return;
  }
  
  // If we can use view API, do. Due to an apple bug, -insertSubview:atIndex: actually wants a LAYER index, which we pass in
  if (canUseViewAPI(self, subnode)) {
    [_view insertSubview:subnode.view atIndex:idx];
  } else {
    [_layer insertSublayer:subnode.layer atIndex:(unsigned int)idx];
  }
}

- (void)addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeLogEvent(self, @"addSubnode: %@", subnode);
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually add subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _addSubnode:subnode];
}

- (void)_addSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);
  
  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
    
  // Don't add subnode if it's already if it's already a subnodes
  ASDisplayNode *oldParent = subnode.supernode;
  if (!subnode || subnode == self || oldParent == self) {
    return;
  }

  [self _insertSubnode:subnode atSubnodeIndex:_subnodes.count sublayerIndex:_layer.sublayers.count andRemoveSubnode:nil];
}

- (void)_addSubnodeViewsAndLayers
{
  for (ASDisplayNode *node in [_subnodes copy]) {
    [self _addSubnodeSubviewOrSublayer:node];
  }
}

- (void)_addSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode
{
    // Due to a bug in Apple's framework we have to use the layer index to insert a subview
    // so just use th ecount of the sublayers to add the subnode
  NSInteger idx = _layer.sublayers.count;
  [self _insertSubnodeSubviewOrSublayer:subnode atIndex:idx];
}

- (void)replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeLogEvent(self, @"replaceSubnode: %@ withSubnode:%@", oldSubnode, replacementSubnode);
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually replace old node with replacement node to node with automaticallyManagesSubnodes=YES. Old Node: %@, replacement node: %@", oldSubnode, replacementSubnode);
  [self _replaceSubnode:oldSubnode withSubnode:replacementSubnode];
}

- (void)_replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  if (replacementSubnode == nil) {
    ASDisplayNodeFailAssert(@"Invalid subnode to replace");
    return;
  }
  
  if (oldSubnode.supernode != self) {
    ASDisplayNodeFailAssert(@"Old Subnode to replace must be a subnode");
    return;
  }

  ASDisplayNodeAssert(!(self.nodeLoaded && !oldSubnode.nodeLoaded), @"We have view loaded, but child node does not.");
  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger subnodeIndex = [_subnodes indexOfObjectIdenticalTo:oldSubnode];
  NSInteger sublayerIndex = NSNotFound;

  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
  // hierarchy and none of this could possibly work.
  if (nodeIsInRasterizedTree(self) == NO) {
    if (_layer) {
      sublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:oldSubnode.layer];
      ASDisplayNodeAssert(sublayerIndex != NSNotFound, @"Somehow oldSubnode's supernode is self, yet we could not find it in our layers to replace");
      if (sublayerIndex == NSNotFound) {
        return;
      }
    }
  }

  [self _insertSubnode:replacementSubnode atSubnodeIndex:subnodeIndex sublayerIndex:sublayerIndex andRemoveSubnode:oldSubnode];
}

- (void)insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ belowSubnode:%@", subnode, below);
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode belowSubnode:below];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode belowSubnode:(ASDisplayNode *)below
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (below.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert below must be a subnode");
    return;
  }

  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger belowSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:below];
  NSInteger belowSublayerIndex = NSNotFound;

  
  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
  // hierarchy and none of this could possibly work.
  if (nodeIsInRasterizedTree(self) == NO) {
    if (_layer) {
      belowSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:below.layer];
      ASDisplayNodeAssert(belowSublayerIndex != NSNotFound, @"Somehow below's supernode is self, yet we could not find it in our layers to reference");
      if (belowSublayerIndex == NSNotFound)
        return;
    }
    
    ASDisplayNodeAssert(belowSubnodeIndex != NSNotFound, @"Couldn't find above in subnodes");
    
    // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to
    // insert it will mess up our calculation
    if (subnode.supernode == self) {
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
  }

  ASDisplayNodeAssert(belowSubnodeIndex != NSNotFound, @"Couldn't find below in subnodes");

  [self _insertSubnode:subnode atSubnodeIndex:belowSubnodeIndex sublayerIndex:belowSublayerIndex andRemoveSubnode:nil];
}

- (void)insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ abodeSubnode: %@", subnode, above);
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode aboveSubnode:above];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode aboveSubnode:(ASDisplayNode *)above
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (above.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert above must be a subnode");
    return;
  }

  ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");

  NSInteger aboveSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:above];
  NSInteger aboveSublayerIndex = NSNotFound;

  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
  // hierarchy and none of this could possibly work.
  if (nodeIsInRasterizedTree(self) == NO) {
    if (_layer) {
      aboveSublayerIndex = [_layer.sublayers indexOfObjectIdenticalTo:above.layer];
      ASDisplayNodeAssert(aboveSublayerIndex != NSNotFound, @"Somehow above's supernode is self, yet we could not find it in our layers to replace");
      if (aboveSublayerIndex == NSNotFound)
        return;
    }
    
    ASDisplayNodeAssert(aboveSubnodeIndex != NSNotFound, @"Couldn't find above in subnodes");

    // If the subnode is already in the subnodes array / sublayers and it's before the below node, removing it to
    // insert it will mess up our calculation
    if (subnode.supernode == self) {
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
  ASDisplayNodeLogEvent(self, @"insertSubnode: %@ atIndex: %td", subnode, idx);
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.automaticallyManagesSubnodes == NO, @"Attempt to manually insert subnode to node with automaticallyManagesSubnodes=YES. Node: %@", subnode);
  [self _insertSubnode:subnode atIndex:idx];
}

- (void)_insertSubnode:(ASDisplayNode *)subnode atIndex:(NSInteger)idx
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);
  
  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (idx > _subnodes.count || idx < 0) {
    ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %zd. Count is %zd", idx, _subnodes.count);
    return;
  }
  
  NSInteger sublayerIndex = NSNotFound;

  // Don't bother figuring out the sublayerIndex if in a rasterized subtree, because there are no layers in the
  // hierarchy and none of this could possibly work.
  if (nodeIsInRasterizedTree(self) == NO) {
    // Account for potentially having other subviews
    if (_layer && idx == 0) {
      sublayerIndex = 0;
    } else if (_layer) {
      ASDisplayNode *positionInRelationTo = (_subnodes.count > 0 && idx > 0) ? _subnodes[idx - 1] : nil;
      if (positionInRelationTo) {
        sublayerIndex = incrementIfFound([_layer.sublayers indexOfObjectIdenticalTo:positionInRelationTo.layer]);
      }
    }
  }

  [self _insertSubnode:subnode atSubnodeIndex:idx sublayerIndex:sublayerIndex andRemoveSubnode:nil];
}

- (void)_removeSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(__instanceLock__);

  // Don't call self.supernode here because that will retain/autorelease the supernode.  This method -_removeSupernode: is often called while tearing down a node hierarchy, and the supernode in question might be in the middle of its -dealloc.  The supernode is never messaged, only compared by value, so this is safe.
  // The particular issue that triggers this edge case is when a node calls -removeFromSupernode on a subnode from within its own -dealloc method.
  if (!subnode || subnode.supernode != self) {
    return;
  }

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
  __instanceLock__.unlock();

  // Clear supernode's reference to us before removing the view from the hierarchy, as _ASDisplayView
  // will trigger us to clear our _supernode pointer in willMoveToSuperview:nil.
  // This may result in removing the last strong reference, triggering deallocation after this method.
  [supernode _removeSubnode:self];

  if (view != nil) {
    [view removeFromSuperview];
  } else if (layer != nil) {
    [layer removeFromSuperlayer];
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

    [self willEnterHierarchy];
    for (ASDisplayNode *subnode in self.subnodes) {
      [subnode __enterHierarchy];
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

    [self didExitHierarchy];
    for (ASDisplayNode *subnode in self.subnodes) {
      [subnode __exitHierarchy];
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
  return ([_subnodes copy] ?: @[]);
}

// NOTE: This method must be dealloc-safe (should not retain self).
- (ASDisplayNode *)supernode
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
              node.pendingTransitionID = pendingTransitionId;
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

      // We only need to explicitly exit hierarchy here if we were rasterized.
      // Otherwise we will exit the hierarchy when our view/layer does so
      // which has some nice carry-over machinery to handle cases where we are removed from a hierarchy
      // and then added into it again shortly after.
      if (parentWasOrIsRasterized && _flags.isInHierarchy) {
        [self __exitHierarchy];
      }
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

  // Manual size calculation via calculateSizeThatFits:
  if (((_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits) ||
      (_layoutSpecBlock != NULL)) == NO) {
    CGSize size = [self calculateSizeThatFits:constrainedSize.max];
    ASDisplayNodeLogEvent(self, @"calculatedSize: %@", NSStringFromCGSize(size));
    return [ASLayout layoutWithLayoutElement:self size:ASSizeRangeClamp(constrainedSize, size) sublayouts:nil];
  }
  
  // Size calcualtion with layout elements
  BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;
  if (measureLayoutSpec) {
    _layoutSpecNumberOfPasses++;
  }

  // Get layout element from the node
  id<ASLayoutElement> layoutElement = [self _layoutElementThatFits:constrainedSize];

  // Certain properties are necessary to set on an element of type ASLayoutSpec
  if (layoutElement.layoutElementType == ASLayoutElementTypeLayoutSpec) {
    ASLayoutSpec *layoutSpec = (ASLayoutSpec *)layoutElement;
    
    NSSet *duplicateElements = [layoutSpec findDuplicatedElementsInSubtree];
    if (duplicateElements.count > 0) {
      ASDisplayNodeFailAssert(@"Node %@ returned a layout spec that contains the same elements in multiple positions. Elements: %@", self, duplicateElements);
      // Use an empty layout spec to avoid crashes
      layoutSpec = [[ASLayoutSpec alloc] init];
    }

    if (_shouldCacheLayoutSpec) {
      _layoutSpec = layoutSpec;
    } else {
      ASDisplayNodeAssert(layoutSpec.isMutable, @"Node %@ returned layout spec %@ that has already been used. Layout specs should always be regenerated.", self, layoutSpec);
    }
    
    layoutSpec.parent = self;
    layoutSpec.isMutable = NO;
  }
  
  // Manually propagate the trait collection here so that any layoutSpec children of layoutSpec will get a traitCollection
  {
    ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
    ASEnvironmentStatePropagateDown(layoutElement, [self environmentTraitCollection]);
  }
  
  BOOL measureLayoutComputation = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutComputation;
  if (measureLayoutComputation) {
    _layoutComputationNumberOfPasses++;
  }

  // Layout element layout creation
  ASLayout *layout = ({
    ASDN::SumScopeTimer t(_layoutComputationTotalTime, measureLayoutComputation);
    [layoutElement layoutThatFits:constrainedSize];
  });
  ASDisplayNodeAssertNotNil(layout, @"[ASLayoutElement layoutThatFits:] should never return nil! %@, %@", self, layout);
    
  // Make sure layoutElementObject of the root layout is `self`, so that the flattened layout will be structurally correct.
  BOOL isFinalLayoutElement = (layout.layoutElement != self);
  if (isFinalLayoutElement) {
    layout.position = CGPointZero;
    layout = [ASLayout layoutWithLayoutElement:self size:layout.size sublayouts:@[layout]];
  }
  ASDisplayNodeLogEvent(self, @"computedLayout: %@", layout);

  return [layout filteredNodeLayoutTree];
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
  
#if ASDISPLAYNODE_ASSERTIONS_ENABLED
  if (ASIsCGSizeValidForSize(constrainedSize) == NO) {
    NSLog(@"Cannot calculate size of node: constrainedSize is infinite and node does not override -calculateSizeThatFits: or specify a preferredSize. Try setting style.preferredSize. Node: %@", [self displayNodeRecursiveDescription]);
  }
#endif

  return ASIsCGSizeValidForSize(constrainedSize) ? constrainedSize : CGSizeZero;
}

- (id<ASLayoutElement>)_layoutElementThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
  
  BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;
  
  if (_shouldCacheLayoutSpec && _layoutSpec != nil) {
    return _layoutSpec;
  } else if (_layoutSpecBlock != NULL) {
    return ({
      ASDN::MutexLocker l(__instanceLock__);
      ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      _layoutSpecBlock(self, constrainedSize);
    });
  } else {
    return ({
      ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
      [self layoutSpecThatFits:constrainedSize];
    });
  }
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
  
  ASDisplayNodeAssert(NO, @"-[ASDisplayNode layoutSpecThatFits:] should never return an empty value. One way this is caused is by calling -[super layoutSpecThatFits:] which is not currently supported.");
  return [[ASLayoutSpec alloc] init];
}

- (void)setLayoutSpecBlock:(ASLayoutSpecBlock)layoutSpecBlock
{
  // For now there should never be an overwrite of layoutSpecThatFits: / layoutElementThatFits: and a layoutSpecBlock
  ASDisplayNodeAssert(!(_methodOverrides & ASDisplayNodeMethodOverrideLayoutSpecThatFits), @"Overwriting layoutSpecThatFits: and providing a layoutSpecBlock block is currently not supported");

  ASDN::MutexLocker l(__instanceLock__);
  _layoutSpecBlock = layoutSpecBlock;
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
  if (_pendingDisplayNodeLayout != nullptr) {
    return _pendingDisplayNodeLayout->layout.size;
  }
  return _calculatedDisplayNodeLayout->layout.size;
}

- (ASSizeRange)constrainedSizeForCalculatedLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_pendingDisplayNodeLayout != nullptr) {
    return _pendingDisplayNodeLayout->constrainedSize;
  }
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

- (void)setNeedsPreload
{
  if (self.isInPreloadState) {
    [self recursivelyPreload];
  }
}

- (void)recursivelyPreload
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
    [node didEnterPreloadState];
  });
}

- (void)recursivelyClearPreloadedData
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
    [node didExitPreloadState];
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
  if (_methodOverrides & ASDisplayNodeMethodOverrideFetchData) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self fetchData];
#pragma clang diagnostic pop
  }
}

- (void)didExitPreloadState
{
  if (_methodOverrides & ASDisplayNodeMethodOverrideClearFetchedData) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self clearFetchedData];
#pragma clang diagnostic pop
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
  
  // For the Preload and Display ranges, we don't want to call -clear* if not being managed by a range controller.
  // Otherwise we get flashing behavior from normal UIKit manipulations like navigation controller push / pop.
  // Still, the interfaceState should be updated to the current state of the node; just don't act on the transition.
  
  // Entered or exited data loading state.
  BOOL nowPreload = ASInterfaceStateIncludesPreload(newState);
  BOOL wasPreload = ASInterfaceStateIncludesPreload(oldState);
  
  if (nowPreload != wasPreload) {
    if (nowPreload) {
      [self didEnterPreloadState];
    } else {
      // We don't want to call -didExitPreloadState on nodes that aren't being managed by a range controller.
      // Otherwise we get flashing behavior from normal UIKit manipulations like navigation controller push / pop.
      if ([self supportsRangeManagedInterfaceState]) {
        [self didExitPreloadState];
      }
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
      [self didEnterDisplayState];
    } else {
      [self didExitDisplayState];
    }
  }

  // Became visible or invisible.  When range-managed, this represents literal visibility - at least one pixel
  // is onscreen.  If not range-managed, we can't guarantee more than the node being present in an onscreen window.
  BOOL nowVisible = ASInterfaceStateIncludesVisible(newState);
  BOOL wasVisible = ASInterfaceStateIncludesVisible(oldState);

  if (nowVisible != wasVisible) {
    if (nowVisible) {
      [self didEnterVisibleState];
    } else {
      [self didExitVisibleState];
    }
  }

  ASDisplayNodeLogEvent(self, @"interfaceStateDidChange: %@, old: %@", NSStringFromASInterfaceState(newState), NSStringFromASInterfaceState(oldState));
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

- (id<ASLayoutElement>)finalLayoutElement
{
  return self;
}

#pragma mark Debugging (Private)

#if ASEVENTLOG_ENABLE
- (ASEventLog *)eventLog
{
  return _eventLog;
}
#endif

- (NSMutableArray<NSDictionary *> *)propertiesForDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  if (self.debugName.length > 0) {
    [result addObject:@{ @"debugName" : ASStringWithQuotesIfMultiword(self.debugName) }];
  }
  return result;
}

- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription
{
  NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
  
  if (self.debugName.length > 0) {
    [result addObject:@{ @"debugName" : ASStringWithQuotesIfMultiword(self.debugName)}];
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
  ASCellNode *cellNode = ASDisplayNodeFindFirstSupernodeOfClass(self.supernode, [ASCellNode class]);
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

#pragma mark - Deprecated

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
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

@end

@implementation ASDisplayNode (Debugging)

- (NSString *)descriptionForRecursiveDescription
{
  NSString *creationTypeString = nil;
#if TIME_DISPLAYNODE_OPS
  creationTypeString = [NSString stringWithFormat:@"cr8:%.2lfms dl:%.2lfms ap:%.2lfms ad:%.2lfms",  1000 * _debugTimeToCreateView, 1000 * _debugTimeForDidLoad, 1000 * _debugTimeToApplyPendingState, 1000 * _debugTimeToAddSubnodeViews];
#endif

  return [NSString stringWithFormat:@"<%@ alpha:%.2f isLayerBacked:%d frame:%@ %@>", self.description, self.alpha, self.isLayerBacked, NSStringFromCGRect(self.frame), creationTypeString];
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
  NSString *string = NSStringFromClass([self class]);
  if (_debugName) {
    string = [string stringByAppendingString:[NSString stringWithFormat:@"\"%@\"",_debugName]];
  }
  return string;
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

#pragma mark - Deprecated

@implementation ASDisplayNode (Deprecated)

- (NSString *)name
{
  return self.debugName;
}

- (void)setName:(NSString *)name
{
  self.debugName = name;
}

- (void)setPreferredFrameSize:(CGSize)preferredFrameSize
{
  // Deprecated preferredFrameSize just calls through to set width and height
  self.style.preferredSize = preferredFrameSize;
  [self setNeedsLayout];
}

- (CGSize)preferredFrameSize
{
  ASLayoutSize size = self.style.preferredLayoutSize;
  BOOL isPoints = (size.width.unit == ASDimensionUnitPoints && size.height.unit == ASDimensionUnitPoints);
  return isPoints ? CGSizeMake(size.width.value, size.height.value) : CGSizeZero;
}

- (CGSize)measure:(CGSize)constrainedSize
{
  return [self layoutThatFits:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;
}

ASLayoutElementStyleForwarding

- (void)visibilityDidChange:(BOOL)isVisible
{
  if (isVisible) {
    [self didEnterVisibleState];
  } else {
    [self didExitVisibleState];
  }
}

- (void)visibleStateDidChange:(BOOL)isVisible
{
  if (isVisible) {
    [self didEnterVisibleState];
  } else {
    [self didExitVisibleState];
  }
}

- (void)displayStateDidChange:(BOOL)inDisplayState
{
  if (inDisplayState) {
    [self didEnterVisibleState];
  } else {
    [self didExitVisibleState];
  }
}

- (void)loadStateDidChange:(BOOL)inLoadState
{
  if (inLoadState) {
    [self didEnterPreloadState];
  } else {
    [self didExitPreloadState];
  }
}

- (void)fetchData
{
  // subclass override
}

- (void)clearFetchedData
{
  // subclass override
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

#pragma mark - ASDisplayNode(LayoutDebugging)

- (void)setShouldVisualizeLayoutSpecs:(BOOL)shouldVisualizeLayoutSpecs
{
  ASDN::MutexLocker l(__instanceLock__);
  if (shouldVisualizeLayoutSpecs != [self shouldVisualizeLayoutSpecs]) {
    if (shouldVisualizeLayoutSpecs) {
      [self enterHierarchyState:ASHierarchyStateVisualizeLayout];
    } else {
      [self exitHierarchyState:ASHierarchyStateVisualizeLayout];
    }
    [self setNeedsLayout];
  }
}

- (BOOL)shouldVisualizeLayoutSpecs
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASHierarchyStateIncludesVisualizeLayout(_hierarchyState);
}

- (void)setShouldCacheLayoutSpec:(BOOL)shouldCacheLayoutSpec
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_shouldCacheLayoutSpec != shouldCacheLayoutSpec) {
    _shouldCacheLayoutSpec = shouldCacheLayoutSpec;
    if (_shouldCacheLayoutSpec == NO) {
      _layoutSpec = nil;
    }
  }
}

- (BOOL)shouldCacheLayoutSpec
{
  ASDN::MutexLocker l(__instanceLock__);
  return _shouldCacheLayoutSpec;
}

@end
