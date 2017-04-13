//
//  ASDisplayNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASDisplayNodeInternal.h>

#import <AsyncDisplayKit/ASDisplayNode+FrameworkSubclasses.h>
#import <AsyncDisplayKit/ASDisplayNode+Beta.h>
#import <AsyncDisplayKit/ASDisplayNode+Deprecated.h>
#import <AsyncDisplayKit/AsyncDisplayKit+Debug.h>
#import <AsyncDisplayKit/ASLayoutSpec+Subclasses.h>
#import <AsyncDisplayKit/ASCellNode+Internal.h>

#import <objc/runtime.h>

#import <AsyncDisplayKit/_ASAsyncTransaction.h>
#import <AsyncDisplayKit/_ASAsyncTransactionContainer+Private.h>
#import <AsyncDisplayKit/_ASCoreAnimationExtras.h>
#import <AsyncDisplayKit/_ASDisplayLayer.h>
#import <AsyncDisplayKit/_ASDisplayView.h>
#import <AsyncDisplayKit/_ASPendingState.h>
#import <AsyncDisplayKit/_ASScopeTimer.h>
#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASDisplayNodeExtras.h>
#import <AsyncDisplayKit/ASEqualityHelpers.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>
#import <AsyncDisplayKit/ASLayoutElementStylePrivate.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>
#import <AsyncDisplayKit/ASLayoutSpecPrivate.h>
#import <AsyncDisplayKit/ASRunLoopQueue.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASWeakProxy.h>
#import <AsyncDisplayKit/ASResponderChainEnumerator.h>

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

static ASDisplayNodeNonFatalErrorBlock _nonFatalErrorBlock = nil;

// Forward declare CALayerDelegate protocol as the iOS 10 SDK moves CALayerDelegate from a formal delegate to a protocol.
// We have to forward declare the protocol as this place otherwise it will not compile compiling with an Base SDK < iOS 10
@protocol CALayerDelegate;

@interface ASDisplayNode () <UIGestureRecognizerDelegate, _ASDisplayLayerDelegate, _ASTransitionContextCompletionDelegate>

/**
 * See ASDisplayNodeInternal.h for ivars
 */

@end

@implementation ASDisplayNode

@dynamic layoutElementType;

@synthesize debugName = _debugName;
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

+ (void)initialize
{
  [super initialize];
  
  if (self != [ASDisplayNode class]) {
    
    // Subclasses should never override these. Use unused to prevent warnings
    __unused NSString *classString = NSStringFromClass(self);
    
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedLayout)), @"Subclass %@ must not override calculatedLayout method.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measure:)), @"Subclass %@ must not override measure: method", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(measureWithSizeRange:)), @"Subclass %@ must not override measureWithSizeRange: method. Instead override calculateLayoutThatFits:", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:)), @"Subclass %@ must not override layoutThatFits: method. Instead override calculateLayoutThatFits:.", classString);
    ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(layoutThatFits:parentSize:)), @"Subclass %@ must not override layoutThatFits:parentSize method. Instead override calculateLayoutThatFits:.", classString);
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
    __block IMP originalLayoutSpecThatFitsIMP = ASReplaceMethodWithBlock(self, @selector(_locked_layoutElementThatFits:), ^(ASDisplayNode *_self, ASSizeRange sizeRange) {
      NSArray *oldSubnodes = _self.subnodes;
      ASLayoutSpec *layoutElement = ((ASLayoutSpec *( *)(id, SEL, ASSizeRange))originalLayoutSpecThatFitsIMP)(_self, @selector(_locked_layoutElementThatFits:), sizeRange);
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
  
  _primitiveTraitCollection = ASPrimitiveTraitCollectionMakeDefault();
  
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
  if (!(self = [self init]))
    return nil;

  ASDisplayNodeAssert([viewClass isSubclassOfClass:[UIView class]], @"should initialize with a subclass of UIView");

  _viewClass = viewClass;
  _flags.synchronous = ![viewClass isSubclassOfClass:[_ASDisplayView class]];

  return self;
}

- (instancetype)initWithLayerClass:(Class)layerClass
{
  if (!(self = [self init])) {
    return nil;
  }

  ASDisplayNodeAssert([layerClass isSubclassOfClass:[CALayer class]], @"should initialize with a subclass of CALayer");

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
  if (!(self = [self init])) {
    return nil;
  }

  [self setViewBlock:viewBlock];
  if (didLoadBlock != nil) {
    [self onDidLoad:didLoadBlock];
  }
  
  return self;
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  return [self initWithLayerBlock:layerBlock didLoadBlock:nil];
}

- (instancetype)initWithLayerBlock:(ASDisplayNodeLayerBlock)layerBlock didLoadBlock:(ASDisplayNodeDidLoadBlock)didLoadBlock
{
  if (!(self = [self init])) {
    return nil;
  }
  
  [self setLayerBlock:layerBlock];
  if (didLoadBlock != nil) {
    [self onDidLoad:didLoadBlock];
  }
  
  return self;
}

- (void)setViewBlock:(ASDisplayNodeViewBlock)viewBlock
{
  ASDisplayNodeAssertFalse(self.nodeLoaded);
  ASDisplayNodeAssertNotNil(viewBlock, @"should initialize with a valid block that returns a UIView");

  _viewBlock = viewBlock;
  _flags.synchronous = YES;
}

- (void)setLayerBlock:(ASDisplayNodeLayerBlock)layerBlock
{
  ASDisplayNodeAssertFalse(self.nodeLoaded);
  ASDisplayNodeAssertNotNil(layerBlock, @"should initialize with a valid block that returns a CALayer");

  _layerBlock = layerBlock;
  _flags.synchronous = YES;
  _flags.layerBacked = YES;
}

- (void)onDidLoad:(ASDisplayNodeDidLoadBlock)body
{
  ASDN::MutexLocker l(__instanceLock__);

  if ([self _locked_isNodeLoaded]) {
    ASDisplayNodeAssertThreadAffinity(self);
    ASDN::MutexUnlocker l(__instanceLock__);
    body(self);
  } else if (_onDidLoadBlocks == nil) {
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
    [subnode _setSupernode:nil];

  // Trampoline any UIKit ivars' deallocation to main
  if (ASDisplayNodeThreadIsMain() == NO) {
    [self _scheduleIvarsForMainDeallocation];
  }

  _subnodes = nil;

#if YOGA
  if (_yogaNode != NULL) {
    YGNodeFree(_yogaNode);
  }
#endif

  // TODO: Remove this? If supernode isn't already nil, this method isn't dealloc-safe anyway.
  [self _setSupernode:nil];
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
 *
 * Result is of type NSValue<[Ivar]>
 */
+ (NSValue * _Nonnull)_ivarsThatMayNeedMainDeallocation
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

    if (type != NULL && strcmp(type, @encode(id)) == 0) {
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

#pragma mark - Loading / Unloading

- (void)__unloadNode
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert([self isNodeLoaded], @"Implementation shouldn't call __unloadNode if not loaded: %@", self);
  ASDisplayNodeAssert(_flags.synchronous == NO, @"Node created using -initWithViewBlock:/-initWithLayerBlock: cannot be unloaded. Node: %@", self);
  ASDN::MutexLocker l(__instanceLock__);

  if (_flags.layerBacked) {
    _pendingViewState = [_ASPendingState pendingViewStateFromLayer:_layer];
  } else {
    _pendingViewState = [_ASPendingState pendingViewStateFromView:_view];
  }
  
  [_view removeFromSuperview];
  _view = nil;
  if (_flags.layerBacked)
    _layer.delegate = nil;
  [_layer removeFromSuperlayer];
  _layer = nil;
}

- (BOOL)_locked_shouldLoadViewOrLayer
{
  return !_flags.isDeallocating && !(_hierarchyState & ASHierarchyStateRasterized);
}

- (UIView *)_locked_viewToLoad
{
  UIView *view = nil;
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
  
  // Special handling of wrapping UIKit components
  if (_flags.synchronous) {
    // UIImageView layers. More details on the flags
    if ([_viewClass isSubclassOfClass:[UIImageView class]]) {
      _flags.canClearContentsOfLayer = NO;
      _flags.canCallSetNeedsDisplayOfLayer = NO;
    }
      
    // UIActivityIndicator
    if ([_viewClass isSubclassOfClass:[UIActivityIndicatorView class]]
        || [_viewClass isSubclassOfClass:[UIVisualEffectView class]]) {
      self.opaque = NO;
    }
  }

  return view;
}

- (CALayer *)_locked_layerToLoad
{
  ASDisplayNodeAssert(_flags.layerBacked, @"_layerToLoad is only for layer-backed nodes");

  CALayer *layer = nil;
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

- (void)_locked_loadViewOrLayerIsLayerBacked:(BOOL)isLayerBacked
{
  if (isLayerBacked) {
    TIME_SCOPED(_debugTimeToCreateView);
    _layer = [self _locked_layerToLoad];
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
    _view = [self _locked_viewToLoad];
    _view.asyncdisplaykit_node = self;
    _layer = _view.layer;
  }
  _layer.asyncdisplaykit_node = self;
  
  self._locked_asyncLayer.asyncDelegate = self;
}

- (void)_didLoad
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  ASDisplayNodeLogEvent(self, @"didLoad");
  TIME_SCOPED(_debugTimeForDidLoad);
  
  [self didLoad];
  
  __instanceLock__.lock();
  NSArray *onDidLoadBlocks = [_onDidLoadBlocks copy];
  _onDidLoadBlocks = nil;
  __instanceLock__.unlock();
  
  for (ASDisplayNodeDidLoadBlock block in onDidLoadBlocks) {
    block(self);
  }
}

- (void)didLoad
{
  ASDisplayNodeAssertMainThread();
  
  // Subclass hook
}

- (BOOL)isNodeLoaded
{
  if (ASDisplayNodeThreadIsMain()) {
    // Because the view and layer can only be created and destroyed on Main, that is also the only thread
    // where the state of this property can change. As an optimization, we can avoid locking.
    return [self _locked_isNodeLoaded];
  } else {
    ASDN::MutexLocker l(__instanceLock__);
    return [self _locked_isNodeLoaded];
  }
}

- (BOOL)_locked_isNodeLoaded
{
  return (_view != nil || (_layer != nil && _flags.layerBacked));
}

#pragma mark - Misc Setter / Getter

- (UIView *)view
{
  ASDN::MutexLocker l(__instanceLock__);

  ASDisplayNodeAssert(!_flags.layerBacked, @"Call to -view undefined on layer-backed nodes");
  BOOL isLayerBacked = _flags.layerBacked;
  if (isLayerBacked) {
    return nil;
  }

  if (_view != nil) {
    return _view;
  }

  if (![self _locked_shouldLoadViewOrLayer]) {
    return nil;
  }
  
  // Loading a view needs to happen on the main thread
  ASDisplayNodeAssertMainThread();
  [self _locked_loadViewOrLayerIsLayerBacked:isLayerBacked];
  
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    // MutexUnlocker will re-lock at the end of scope.
    ASDN::MutexUnlocker u(__instanceLock__);
    [self __setNeedsLayout];
  }
  
  [self _locked_applyPendingStateToViewOrLayer];
  
  {
    // The following methods should not be called with a lock
    ASDN::MutexUnlocker u(__instanceLock__);

    // No need for the lock as accessing the subviews or layers are always happening on main
    [self _addSubnodeViewsAndLayers];
    
    // A subclass hook should never be called with a lock
    [self _didLoad];
  }

  return _view;
}

- (CALayer *)layer
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_layer != nil) {
    return _layer;
  }
  
  BOOL isLayerBacked = _flags.layerBacked;
  if (!isLayerBacked) {
    // No need for the lock and call the view explicitly in case it needs to be loaded first
    ASDN::MutexUnlocker u(__instanceLock__);
    return self.view.layer;
  }
  
  if (![self _locked_shouldLoadViewOrLayer]) {
    return nil;
  }
  
  // Loading a layer needs to happen on the main thread
  ASDisplayNodeAssertMainThread();
  [self _locked_loadViewOrLayerIsLayerBacked:isLayerBacked];
  
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    // MutexUnlocker will re-lock at the end of scope.
    ASDN::MutexUnlocker u(__instanceLock__);
    [self __setNeedsLayout];
  }
  
  [self _locked_applyPendingStateToViewOrLayer];
  
  {
    // The following methods should not be called with a lock
    ASDN::MutexUnlocker u(__instanceLock__);

    // No need for the lock as accessing the subviews or layers are always happening on main
    [self _addSubnodeViewsAndLayers];
    
    // A subclass hook should never be called with a lock
    [self _didLoad];
  }

  return _layer;
}

// Returns nil if the layer is not an _ASDisplayLayer; will not create the layer if nil.
- (_ASDisplayLayer *)asyncLayer
{
  ASDN::MutexLocker l(__instanceLock__);
  return [self _locked_asyncLayer];
}

- (_ASDisplayLayer *)_locked_asyncLayer
{
  return [_layer isKindOfClass:[_ASDisplayLayer class]] ? (_ASDisplayLayer *)_layer : nil;
}

- (BOOL)isSynchronous
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.synchronous;
}

- (void)setSynchronous:(BOOL)flag
{
  ASDN::MutexLocker l(__instanceLock__);
  _flags.synchronous = flag;
}

- (void)setLayerBacked:(BOOL)isLayerBacked
{
  if (![self.class layerBackedNodesEnabled]) {
    return;
  }

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

#pragma mark - Layout

#if DEBUG
  #define AS_DEDUPE_LAYOUT_SPEC_TREE 1
#endif

// At most a layoutSpecBlock or one of the three layout methods is overridden
#define __ASDisplayNodeCheckForLayoutMethodOverrides \
    ASDisplayNodeAssert(_layoutSpecBlock != NULL || \
    ((ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateSizeThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(layoutSpecThatFits:)) ? 1 : 0) \
    + (ASDisplayNodeSubclassOverridesSelector(self.class, @selector(calculateLayoutThatFits:)) ? 1 : 0)) <= 1, \
    @"Subclass %@ must at least provide a layoutSpecBlock or override at most one of the three layout methods: calculateLayoutThatFits:, layoutSpecThatFits:, or calculateSizeThatFits:", NSStringFromClass(self.class))

#pragma mark <ASLayoutElement>

- (ASLayoutElementStyle *)style
{
  ASDN::MutexLocker l(__instanceLock__);
  if (_style == nil) {
    _style = [[ASLayoutElementStyle alloc] init];
  }
  return _style;
}

- (ASLayoutElementType)layoutElementType
{
  return ASLayoutElementTypeDisplayNode;
}

- (BOOL)canLayoutAsynchronous
{
  return !self.isNodeLoaded;
}

- (NSArray<id<ASLayoutElement>> *)sublayoutElements
{
  return self.subnodes;
}

- (instancetype)styledWithBlock:(AS_NOESCAPE void (^)(__kindof ASLayoutElementStyle *style))styleBlock
{
  styleBlock(self.style);
  return self;
}

ASLayoutElementFinalLayoutElementDefault

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

#pragma mark Measurement Pass

- (ASLayout *)layoutThatFits:(ASSizeRange)constrainedSize
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // For now we just call the deprecated measureWithSizeRange: method to not break old API
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
  
  // Create a pending display node layout for the layout pass
  _pendingDisplayNodeLayout = std::make_shared<ASDisplayNodeLayout>(
    [self calculateLayoutThatFits:constrainedSize restrictedToSize:self.style.size relativeToParentSize:parentSize],
    constrainedSize,
    parentSize
  );
  
  ASDisplayNodeAssertNotNil(_pendingDisplayNodeLayout->layout, @"-[ASDisplayNode layoutThatFits:parentSize:] _pendingDisplayNodeLayout->layout should not be nil! %@", self);
  return _pendingDisplayNodeLayout->layout ?: [ASLayout layoutWithLayoutElement:self size:{0, 0}];
}

#pragma mark Layout Pass

- (void)__setNeedsLayout
{
  [self invalidateCalculatedLayout];
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

#if YOGA
  [self invalidateCalculatedYogaLayout];
#endif
}

- (void)__layout
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  {
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
    if (_transitionInProgress) {
      return;
    }
    
    // This method will confirm that the layout is up to date (and update if needed).
    // Importantly, it will also APPLY the layout to all of our subnodes if (unless parent is transitioning).
    [self _locked_measureNodeWithBoundsIfNecessary:bounds];
    _pendingDisplayNodeLayout = nullptr;
    
    [self _locked_layoutPlaceholderIfNecessary];
  }
  
  [self _layoutSublayouts];
  
  ASPerformBlockOnMainThread(^{
    [self layout];
    [self layoutDidFinish];
  });
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
  ASLayoutElementContext context = ASLayoutElementGetCurrentContext();
  if (ASLayoutElementContextIsNull(context)) {
    context = ASLayoutElementContextMake(ASLayoutElementContextDefaultTransitionID);
    ASLayoutElementSetCurrentContext(context);
    didCreateNewContext = YES;
  }
  
  // Figure out previous and pending layouts for layout transition
  std::shared_ptr<ASDisplayNodeLayout> nextLayout = _pendingDisplayNodeLayout;
  #define layoutSizeDifferentFromBounds !CGSizeEqualToSize(nextLayout->layout.size, boundsSizeForLayout)
  
  // nextLayout was likely created by a call to layoutThatFits:, check if it is valid and can be applied.
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
    [self _setNeedsLayoutFromAbove];
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
  // TODO: The logic in -_setNeedsLayoutFromAbove seems correct and doesn't use this method.
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

- (void)layoutDidFinish
{
  // Hook for subclasses
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
}

#pragma mark Calculation

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
                     restrictedToSize:(ASLayoutElementSize)size
                 relativeToParentSize:(CGSize)parentSize
{
  ASSizeRange styleAndParentSize = ASLayoutElementSizeResolve(self.style.size, parentSize);
  const ASSizeRange resolvedRange = ASSizeRangeIntersect(constrainedSize, styleAndParentSize);
  return [self calculateLayoutThatFits:resolvedRange];
}

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;

  ASDN::MutexLocker l(__instanceLock__);

#if YOGA /* YOGA */
  if (ASHierarchyStateIncludesYogaLayoutEnabled(_hierarchyState) == YES &&
      ASHierarchyStateIncludesYogaLayoutMeasuring(_hierarchyState) == NO) {
    ASDN::MutexUnlocker ul(__instanceLock__);
    [self calculateLayoutFromYogaRoot:constrainedSize];
  }

  if (ASHierarchyStateIncludesYogaLayoutEnabled(_hierarchyState) == YES && self.yogaCalculatedLayout) {
    return self.yogaCalculatedLayout;
  }
#endif /* YOGA */

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
  id<ASLayoutElement> layoutElement = [self _locked_layoutElementThatFits:constrainedSize];

  // Certain properties are necessary to set on an element of type ASLayoutSpec
  if (layoutElement.layoutElementType == ASLayoutElementTypeLayoutSpec) {
    ASLayoutSpec *layoutSpec = (ASLayoutSpec *)layoutElement;
  
#if AS_DEDUPE_LAYOUT_SPEC_TREE
    NSSet *duplicateElements = [layoutSpec findDuplicatedElementsInSubtree];
    if (duplicateElements.count > 0) {
      ASDisplayNodeFailAssert(@"Node %@ returned a layout spec that contains the same elements in multiple positions. Elements: %@", self, duplicateElements);
      // Use an empty layout spec to avoid crashes
      layoutSpec = [[ASLayoutSpec alloc] init];
    }
#endif

    ASDisplayNodeAssert(layoutSpec.isMutable, @"Node %@ returned layout spec %@ that has already been used. Layout specs should always be regenerated.", self, layoutSpec);
    
    layoutSpec.isMutable = NO;
  }
  
  // Manually propagate the trait collection here so that any layoutSpec children of layoutSpec will get a traitCollection
  {
    
    ASDN::SumScopeTimer t(_layoutSpecTotalTime, measureLayoutSpec);
    ASTraitCollectionPropagateDown(layoutElement, self.primitiveTraitCollection);
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

- (id<ASLayoutElement>)_locked_layoutElementThatFits:(ASSizeRange)constrainedSize
{
  __ASDisplayNodeCheckForLayoutMethodOverrides;
  
  BOOL measureLayoutSpec = _measurementOptions & ASDisplayNodePerformanceMeasurementOptionLayoutSpec;
  
  if (_layoutSpecBlock != NULL) {
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
  // For now there should never be an override of layoutSpecThatFits: / layoutElementThatFits: and a layoutSpecBlock
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

- (void)_setCalculatedDisplayNodeLayout:(std::shared_ptr<ASDisplayNodeLayout>)displayNodeLayout
{
  ASDN::MutexLocker l(__instanceLock__);
  [self _locked_setCalculatedDisplayNodeLayout:displayNodeLayout];
}

- (void)_locked_setCalculatedDisplayNodeLayout:(std::shared_ptr<ASDisplayNodeLayout>)displayNodeLayout
{
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

/**
 * @abstract Informs the root node that the intrinsic size of the receiver is no longer valid.
 *
 * @discussion The size of a root node is determined by each subnode. Calling invalidateSize will let the root node know
 * that the intrinsic size of the receiver node is no longer valid and a resizing of the root node needs to happen.
 */
- (void)_setNeedsLayoutFromAbove
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Mark the node for layout in the next layout pass
  [self setNeedsLayout];
  
  __instanceLock__.lock();
  // Escalate to the root; entire tree must allow adjustments so the layout fits the new child.
  // Much of the layout will be re-used as cached (e.g. other items in an unconstrained stack)
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  if (supernode) {
    // Threading model requires that we unlock before calling a method on our parent.
    [supernode _setNeedsLayoutFromAbove];
  } else {
    // Let the root node method know that the size was invalidated
    [self _rootNodeDidInvalidateSize];
  }
}

- (void)_rootNodeDidInvalidateSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  __instanceLock__.lock();
  
  // We are the root node and need to re-flow the layout; at least one child needs a new size.
  CGSize boundsSizeForLayout = ASCeilSizeValues(self.bounds.size);

  // Figure out constrainedSize to use
  ASSizeRange constrainedSize = ASSizeRangeMake(boundsSizeForLayout);
  if (_pendingDisplayNodeLayout != nullptr) {
    constrainedSize = _pendingDisplayNodeLayout->constrainedSize;
  } else if (_calculatedDisplayNodeLayout->layout != nil) {
    constrainedSize = _calculatedDisplayNodeLayout->constrainedSize;
  }

  __instanceLock__.unlock();

  // Perform a measurement pass to get the full tree layout, adapting to the child's new size.
  ASLayout *layout = [self layoutThatFits:constrainedSize];
  
  // Check if the returned layout has a different size than our current bounds.
  if (CGSizeEqualToSize(boundsSizeForLayout, layout.size) == NO) {
    // If so, inform our container we need an update (e.g Table, Collection, ViewController, etc).
    [self displayNodeDidInvalidateSizeNewSize:layout.size];
  }
}

- (void)displayNodeDidInvalidateSizeNewSize:(CGSize)size
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
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

- (void)layout
{
  ASDisplayNodeAssertMainThread();
  // Subclass hook
}

- (void)_layoutSublayouts
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  ASLayout *layout;
  NSArray<ASDisplayNode *> *subnodes;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_calculatedDisplayNodeLayout->isDirty() || _subnodes.count == 0) {
      return;
    }
    layout = _calculatedDisplayNodeLayout->layout;
    subnodes = [_subnodes copy];
  }
  
  for (ASDisplayNode *node in subnodes) {
    CGRect frame = [layout frameForElement:node];
    if (CGRectIsNull(frame)) {
      // There is no frame for this node in our layout.
      // This currently can happen if we get a CA layout pass
      // while waiting for the client to run animateLayoutTransition:
    } else {
      node.frame = frame;
    }
  }
}

#pragma mark Automatically Manages Subnodes

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

#pragma mark Layout Transition

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
      
      ASLayoutElementSetCurrentContext(ASLayoutElementContextMake(transitionID));

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
      ASLayoutTransition *pendingLayoutTransition;
      _ASTransitionContext *pendingLayoutTransitionContext;
      {
        // Grab __instanceLock__ here to make sure this transition isn't invalidated
        // right after it passed the validation test and before it proceeds
        ASDN::MutexLocker l(__instanceLock__);
        
        if ([self _locked_shouldAbortTransitionWithID:transitionID]) {
          return;
        }
        
        // Update calculated layout
        auto previousLayout = _calculatedDisplayNodeLayout;
        auto pendingLayout = std::make_shared<ASDisplayNodeLayout>(
                                                                   newLayout,
                                                                   constrainedSize,
                                                                   constrainedSize.max
                                                                   );
        [self _locked_setCalculatedDisplayNodeLayout:pendingLayout];
        
        // Setup pending layout transition for animation
        _pendingLayoutTransition = pendingLayoutTransition = [[ASLayoutTransition alloc] initWithNode:self
                                                                                        pendingLayout:pendingLayout
                                                                                       previousLayout:previousLayout];
        // Setup context for pending layout transition. we need to hold a strong reference to the context
        _pendingLayoutTransitionContext = pendingLayoutTransitionContext = [[_ASTransitionContext alloc] initWithAnimation:animated
                                                                                                            layoutDelegate:_pendingLayoutTransition
                                                                                                        completionDelegate:self];
      }
      
      // Apply complete layout transitions for all subnodes
      ASDisplayNodePerformBlockOnEverySubnode(self, NO, ^(ASDisplayNode * _Nonnull node) {
        [node _completePendingLayoutTransition];
        node.hierarchyState &= (~ASHierarchyStateLayoutPending);
      });
      
      // Measurement pass completion
      // Give the subclass a change to hook into before calling the completion block
      [self _layoutTransitionMeasurementDidFinish];
      if (completion) {
        completion();
      }
      
      // Apply the subnode insertion immediately to be able to animate the nodes
      [pendingLayoutTransition applySubnodeInsertions];
      
      // Kick off animating the layout transition
      [self animateLayoutTransition:pendingLayoutTransitionContext];
      
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
  __instanceLock__.lock();
  BOOL transitionInProgress = _transitionInProgress;
  __instanceLock__.unlock();
  
  if (transitionInProgress) {
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

- (void)_layoutTransitionMeasurementDidFinish
{
  // No-Op in ASDisplayNode
}

- (void)_finishOrCancelTransition
{
  ASDN::MutexLocker l(__instanceLock__);
  _transitionInProgress = NO;
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

- (BOOL)_shouldAbortTransitionWithID:(int32_t)transitionID
{
  ASDN::MutexLocker l(__instanceLock__);
  return [self _locked_shouldAbortTransitionWithID:transitionID];
}

- (BOOL)_locked_shouldAbortTransitionWithID:(int32_t)transitionID
{
  return (!_transitionInProgress || _transitionID != transitionID);
}

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

#pragma mark <LayoutTransitioning>

/*
 * Hook for subclasses to perform an animation based on the given ASContextTransitioning. By default a fade in and out
 * animation is provided.
 */
- (void)animateLayoutTransition:(id<ASContextTransitioning>)context
{
  if ([context isAnimated] == NO) {
    [self _layoutSublayouts];
    [context completeTransition:YES];
    return;
  }
 
  ASDisplayNode *node = self;
  
  NSAssert(node.isNodeLoaded == YES, @"Invalid node state");
  
  NSArray<ASDisplayNode *> *removedSubnodes = [context removedSubnodes];
  NSMutableArray<ASDisplayNode *> *insertedSubnodes = [[context insertedSubnodes] mutableCopy];
  NSMutableArray<ASDisplayNode *> *movedSubnodes = [NSMutableArray array];
  
  NSMutableArray<_ASAnimatedTransitionContext *> *insertedSubnodeContexts = [NSMutableArray array];
  NSMutableArray<_ASAnimatedTransitionContext *> *removedSubnodeContexts = [NSMutableArray array];
  
  for (ASDisplayNode *subnode in [context subnodesForKey:ASTransitionContextToLayoutKey]) {
    if ([insertedSubnodes containsObject:subnode] == NO) {
      // This is an existing subnode, check if it is resized, moved or both
      CGRect fromFrame = [context initialFrameForNode:subnode];
      CGRect toFrame = [context finalFrameForNode:subnode];
      if (CGSizeEqualToSize(fromFrame.size, toFrame.size) == NO) {
        [insertedSubnodes addObject:subnode];
      }
      if (CGPointEqualToPoint(fromFrame.origin, toFrame.origin) == NO) {
        [movedSubnodes addObject:subnode];
      }
    }
  }
  
  // Create contexts for inserted and removed subnodes
  for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
    [insertedSubnodeContexts addObject:[_ASAnimatedTransitionContext contextForNode:insertedSubnode alpha:insertedSubnode.alpha]];
  }
  for (ASDisplayNode *removedSubnode in removedSubnodes) {
    [removedSubnodeContexts addObject:[_ASAnimatedTransitionContext contextForNode:removedSubnode alpha:removedSubnode.alpha]];
  }
  
  // Fade out inserted subnodes
  for (ASDisplayNode *insertedSubnode in insertedSubnodes) {
    insertedSubnode.frame = [context finalFrameForNode:insertedSubnode];
    insertedSubnode.alpha = 0;
  }
  
  // Adjust groupOpacity for animation
  BOOL originAllowsGroupOpacity = node.allowsGroupOpacity;
  node.allowsGroupOpacity = YES;

  [UIView animateWithDuration:self.defaultLayoutTransitionDuration delay:self.defaultLayoutTransitionDelay options:self.defaultLayoutTransitionOptions animations:^{
    // Fade removed subnodes and views out
    for (ASDisplayNode *removedSubnode in removedSubnodes) {
      removedSubnode.alpha = 0;
    }
    
    // Fade inserted subnodes in
    for (_ASAnimatedTransitionContext *insertedSubnodeContext in insertedSubnodeContexts) {
      insertedSubnodeContext.node.alpha = insertedSubnodeContext.alpha;
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
    // Restore all removed subnode alpha values
    for (_ASAnimatedTransitionContext *removedSubnodeContext in removedSubnodeContexts) {
      removedSubnodeContext.node.alpha = removedSubnodeContext.alpha;
    }
    
    // Restore group opacity
    node.allowsGroupOpacity = originAllowsGroupOpacity;
    
    // Subnode removals are automatically performed
    [context completeTransition:finished];
  }];
}

/**
 * Hook for subclasses to clean up nodes after the transition happened. Furthermore this can be used from subclasses
 * to manually perform deletions.
 */
- (void)didCompleteLayoutTransition:(id<ASContextTransitioning>)context
{
  __instanceLock__.lock();
  ASLayoutTransition *pendingLayoutTransition = _pendingLayoutTransition;
  __instanceLock__.unlock();

  [pendingLayoutTransition applySubnodeRemovals];
}

#pragma mark <_ASTransitionContextCompletionDelegate>

/**
 * After completeTransition: is called on the ASContextTransitioning object in animateLayoutTransition: this
 * delegate method will be called that start the completion process of the transition
 */
- (void)transitionContext:(_ASTransitionContext *)context didComplete:(BOOL)didComplete
{
  ASDisplayNodeAssertMainThread();

  [self didCompleteLayoutTransition:context];
  
  _pendingLayoutTransitionContext = nil;

  [self _pendingLayoutTransitionDidComplete];
}

/**
 * Completes the pending layout transition immediately without going through the the Layout Transition Animation API
 */
- (void)_completePendingLayoutTransition
{
  __instanceLock__.lock();
  ASLayoutTransition *pendingLayoutTransition = _pendingLayoutTransition;
  __instanceLock__.unlock();

  if (pendingLayoutTransition != nil) {
    [self _setCalculatedDisplayNodeLayout:pendingLayoutTransition.pendingLayout];
    [self _completeLayoutTransition:pendingLayoutTransition];
  }
  [self _pendingLayoutTransitionDidComplete];
}

/**
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
  // Subclass hook
  [self calculatedLayoutDidChange];
  
  // Grab lock after calling out to subclass
  ASDN::MutexLocker l(__instanceLock__);

  // We generate placeholders at measureWithSizeRange: time so that a node is guaranteed to have a placeholder ready to go.
  // This is also because measurement is usually asynchronous, but placeholders need to be set up synchronously.
  // First measurement is guaranteed to be before the node is onscreen, so we can create the image async. but still have it appear sync.
  if (_placeholderEnabled && !_placeholderImage && [self _locked_displaysAsynchronously]) {
    
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

#pragma mark - Display

NSString * const ASRenderingEngineDidDisplayScheduledNodesNotification = @"ASRenderingEngineDidDisplayScheduledNodes";
NSString * const ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp = @"ASRenderingEngineDidDisplayNodesScheduledBeforeTimestamp";

- (BOOL)displaysAsynchronously
{
  ASDN::MutexLocker l(__instanceLock__);
  return [self _locked_displaysAsynchronously];
}

/**
 * Core implementation of -displaysAsynchronously.
 */
- (BOOL)_locked_displaysAsynchronously
{
  return _flags.synchronous == NO && _flags.displaysAsynchronously;
}

- (void)setDisplaysAsynchronously:(BOOL)displaysAsynchronously
{
  ASDisplayNodeAssertThreadAffinity(self);
  
  ASDN::MutexLocker l(__instanceLock__);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.synchronous) {
    return;
  }

  if (_flags.displaysAsynchronously == displaysAsynchronously) {
    return;
  }

  _flags.displaysAsynchronously = displaysAsynchronously;

  self._locked_asyncLayer.displaysAsynchronously = displaysAsynchronously;
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
  ASDN::MutexLocker l(__instanceLock__);

  return _contentsScaleForDisplay;
}

- (void)setContentsScaleForDisplay:(CGFloat)contentsScaleForDisplay
{
  ASDN::MutexLocker l(__instanceLock__);

  if (_contentsScaleForDisplay == contentsScaleForDisplay) {
    return;
  }

  _contentsScaleForDisplay = contentsScaleForDisplay;
}

- (void)displayImmediately
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.synchronous, @"this method is designed for asynchronous mode only");

  [self.asyncLayer displayImmediately];
}

- (void)recursivelyDisplayImmediately
{
  for (ASDisplayNode *child in self.subnodes) {
    [child recursivelyDisplayImmediately];
  }
  [self displayImmediately];
}

- (void)__setNeedsDisplay
{
  BOOL shouldScheduleForDisplay = NO;
  {
    ASDN::MutexLocker l(__instanceLock__);
    BOOL nowDisplay = ASInterfaceStateIncludesDisplay(_interfaceState);
    // FIXME: This should not need to recursively display, so create a non-recursive variant.
    // The semantics of setNeedsDisplay (as defined by CALayer behavior) are not recursive.
    if (_layer != nil && !_flags.synchronous && nowDisplay && [self _implementsDisplay]) {
      shouldScheduleForDisplay = YES;
    }
  }
  
  if (shouldScheduleForDisplay) {
    [ASDisplayNode scheduleNodeForRecursiveDisplay:self];
  }
}

+ (void)scheduleNodeForRecursiveDisplay:(ASDisplayNode *)node
{
  static dispatch_once_t onceToken;
  static ASRunLoopQueue<ASDisplayNode *> *renderQueue;
  dispatch_once(&onceToken, ^{
    renderQueue = [[ASRunLoopQueue<ASDisplayNode *> alloc] initWithRunLoop:CFRunLoopGetMain()
                                                             retainObjects:NO
                                                                   handler:^(ASDisplayNode * _Nonnull dequeuedItem, BOOL isQueueDrained) {
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

/// Helper method to summarize whether or not the node run through the display process
- (BOOL)_implementsDisplay
{
  ASDN::MutexLocker l(__instanceLock__);
  
  return _flags.implementsDrawRect || _flags.implementsImageDisplay || _flags.shouldRasterizeDescendants ||
  _flags.implementsInstanceDrawRect || _flags.implementsInstanceImageDisplay;
}

// Track that a node will be displayed as part of the current node hierarchy.
// The node sending the message should usually be passed as the parameter, similar to the delegation pattern.
- (void)_pendingNodeWillDisplay:(ASDisplayNode *)node
{
  ASDisplayNodeAssertMainThread();

  // No lock needed as _pendingDisplayNodes is main thread only
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

  // No lock for _pendingDisplayNodes needed as it's main thread only
  [_pendingDisplayNodes removeObject:node];

  if (_pendingDisplayNodes.isEmpty) {
    
    [self hierarchyDisplayDidFinish];
    BOOL placeholderShouldPersist = [self placeholderShouldPersist];

    __instanceLock__.lock();
    if (_placeholderLayer.superlayer && !placeholderShouldPersist) {
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
    __instanceLock__.unlock();
  }
}

- (void)hierarchyDisplayDidFinish
{
  // Subclass hook
}

// Helper method to determine if it's safe to call setNeedsDisplay on a layer without throwing away the content.
// For details look at the comment on the canCallSetNeedsDisplayOfLayer flag
- (BOOL)_canCallSetNeedsDisplayOfLayer
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.canCallSetNeedsDisplayOfLayer;
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
  
  if (node.isSynchronous && [node _canCallSetNeedsDisplayOfLayer]) {
    // Layers for UIKit components that are wrapped within a node needs to be set to be displayed as the contents of
    // the layer get's cleared and would not be recreated otherwise.
    // We do not call this for _ASDisplayLayer as an optimization.
    [layer setNeedsDisplay];
  }
  
  if ([node _implementsDisplay]) {
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
  ASDN::MutexLocker l(__instanceLock__);
  _flags.shouldBypassEnsureDisplay = shouldBypassEnsureDisplay;
}

- (BOOL)shouldBypassEnsureDisplay
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.shouldBypassEnsureDisplay;
}

- (void)setNeedsDisplayAtScale:(CGFloat)contentsScale
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (contentsScale == _contentsScaleForDisplay) {
      return;
    }
    
    _contentsScaleForDisplay = contentsScale;
  }

  [self setNeedsDisplay];
}

- (void)recursivelySetNeedsDisplayAtScale:(CGFloat)contentsScale
{
  ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode *node) {
    [node setNeedsDisplayAtScale:contentsScale];
  });
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
  __instanceLock__.lock();

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.synchronous || _flags.displaySuspended == flag) {
    __instanceLock__.unlock();
    return;
  }

  _flags.displaySuspended = flag;

  self._locked_asyncLayer.displaySuspended = flag;
  
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();

  if ([self _implementsDisplay]) {
    // Display start and finish methods needs to happen on the main thread
    ASPerformBlockOnMainThread(^{
      if (flag) {
        [supernode subnodeDisplayDidFinish:self];
      } else {
        [supernode subnodeDisplayWillStart:self];
      }
    });
  }
}

NSInteger const ASDefaultDrawingPriority = ASDefaultTransactionPriority;
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
  
  if (!_flags.hasCustomDrawingPriority) {
    return ASDefaultDrawingPriority;
  } else {
    return [objc_getAssociatedObject(self, ASDisplayNodeDrawingPriorityKey) integerValue];
  }
}


#pragma mark <_ASDisplayLayerDelegate>

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

- (void)displayWillStart {}
- (void)displayWillStartAsynchronously:(BOOL)asynchronously
{
  [self displayWillStart]; // Subclass override
  ASDisplayNodeAssertMainThread();

  ASDisplayNodeLogEvent(self, @"displayWillStart");
  // in case current node takes longer to display than it's subnodes, treat it as a dependent node
  [self _pendingNodeWillDisplay:self];
  
  __instanceLock__.lock();
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  [supernode subnodeDisplayWillStart:self];
}

- (void)displayDidFinish
{
  ASDisplayNodeAssertMainThread();
  
  ASDisplayNodeLogEvent(self, @"displayDidFinish");
  [self _pendingNodeDidDisplay:self];

  __instanceLock__.lock();
  ASDisplayNode *supernode = _supernode;
  __instanceLock__.unlock();
  
  [supernode subnodeDisplayDidFinish:self];
}

- (void)subnodeDisplayWillStart:(ASDisplayNode *)subnode
{
  // Subclass hook
  [self _pendingNodeWillDisplay:subnode];
}

- (void)subnodeDisplayDidFinish:(ASDisplayNode *)subnode
{
  // Subclass hook
  [self _pendingNodeDidDisplay:subnode];
}

#pragma mark <CALayerDelegate>

// We are only the delegate for the layer when we are layer-backed, as UIView performs this function normally
- (id<CAAction>)actionForLayer:(CALayer *)layer forKey:(NSString *)event
{
  if (event == kCAOnOrderIn) {
    [self __enterHierarchy];
  } else if (event == kCAOnOrderOut) {
    [self __exitHierarchy];
  }

  ASDisplayNodeAssert(_flags.layerBacked, @"We shouldn't get called back here unless we are layer-backed.");
  return (id)kCFNull;
}

#pragma mark - Error Handling

+ (void)setNonFatalErrorBlock:(ASDisplayNodeNonFatalErrorBlock)nonFatalErrorBlock
{
  if (_nonFatalErrorBlock != nonFatalErrorBlock) {
    _nonFatalErrorBlock = [nonFatalErrorBlock copy];
  }
}

+ (ASDisplayNodeNonFatalErrorBlock)nonFatalErrorBlock
{
  return _nonFatalErrorBlock;
}

#pragma mark - Converting to and from the Node's Coordinate System

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
  
  /**
   * When passed node=nil, all methods in this family use the UIView-style
   * behavior – that is, convert from/to window coordinates if there's a window,
   * otherwise return the point untransformed.
   */
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertPoint:point fromLayer:window.layer];
    } else {
      return point;
    }
  }
  
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
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertPoint:point toLayer:window.layer];
    } else {
      return point;
    }
  }
  
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
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertRect:rect fromLayer:window.layer];
    } else {
      return rect;
    }
  }
  
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
  
  if (node == nil && self.nodeLoaded) {
    CALayer *layer = self.layer;
    if (UIWindow *window = ASFindWindowOfLayer(layer)) {
      return [layer convertRect:rect toLayer:window.layer];
    } else {
      return rect;
    }
  }
  
  // Get root node of the accessible node hierarchy, if node not specified
  node = node ? : ASDisplayNodeUltimateParentOfNode(self);

  // Calculate transform to map points between coordinate spaces
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
  CGAffineTransform flattenedTransform = CATransform3DGetAffineTransform(nodeTransform);
  ASDisplayNodeAssertTrue(CATransform3DIsAffine(nodeTransform));

  // Apply to rect
  return CGRectApplyAffineTransform(rect, flattenedTransform);
}

#pragma mark - Managing the Node Hierarchy

ASDISPLAYNODE_INLINE bool shouldDisableNotificationsForMovingBetweenParents(ASDisplayNode *from, ASDisplayNode *to) {
  if (!from || !to) return NO;
  if (from.isSynchronous) return NO;
  if (to.isSynchronous) return NO;
  if (from.isInHierarchy != to.isInHierarchy) return NO;
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
  return (node.shouldRasterizeDescendants || (node.hierarchyState & ASHierarchyStateRasterized));
}

// NOTE: This method must be dealloc-safe (should not retain self).
- (ASDisplayNode *)supernode
{
#if CHECK_LOCKING_SAFETY
  if (__instanceLock__.ownedByCurrentThread()) {
    NSLog(@"WARNING: Accessing supernode while holding recursive instance lock of this node is worrisome. It's likely that you will soon try to acquire the supernode's lock, and this can easily cause deadlocks.");
  }
#endif
  
  ASDN::MutexLocker l(__instanceLock__);
  return _supernode;
}

- (void)_setSupernode:(ASDisplayNode *)newSupernode
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
      ASTraitCollectionPropagateDown(self, newSupernode.primitiveTraitCollection);
      
    } else {
      // If a node will be removed from the supernode it should go out from the layout pending state to remove all
      // layout pending state related properties on the node
      stateToEnterOrExit |= ASHierarchyStateLayoutPending;
      
      [self exitHierarchyState:stateToEnterOrExit];

      // We only need to explicitly exit hierarchy here if we were rasterized.
      // Otherwise we will exit the hierarchy when our view/layer does so
      // which has some nice carry-over machinery to handle cases where we are removed from a hierarchy
      // and then added into it again shortly after.
      __instanceLock__.lock();
      BOOL isInHierarchy = _flags.isInHierarchy;
      __instanceLock__.unlock();
      
      if (parentWasOrIsRasterized && isInHierarchy) {
        [self __exitHierarchy];
      }
    }
  }
}

- (NSArray *)subnodes
{
  ASDN::MutexLocker l(__instanceLock__);
  return ([_subnodes copy] ?: @[]);
}

/*
 * Central private helper method that should eventually be called if submethods add, insert or replace subnodes
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
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  if (subnode == nil || subnode == self) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode or self as subnode");
    return;
  }
  
  if (subnodeIndex == NSNotFound) {
    ASDisplayNodeFailAssert(@"Try to insert node on an index that was not found");
    return;
  }
  
  if (self.layerBacked && !subnode.layerBacked) {
    ASDisplayNodeFailAssert(@"Cannot add a view-backed node as a subnode of a layer-backed node. Supernode: %@, subnode: %@", self, subnode);
    return;
  }

  __instanceLock__.lock();
    NSUInteger subnodesCount = _subnodes.count;
  __instanceLock__.unlock();
  if (subnodeIndex > subnodesCount || subnodeIndex < 0) {
    ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %zd. Count is %zd", subnodeIndex, subnodesCount);
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
  
  __instanceLock__.lock();
    if (_subnodes == nil) {
      _subnodes = [[NSMutableArray alloc] init];
    }
    [_subnodes insertObject:subnode atIndex:subnodeIndex];
  __instanceLock__.unlock();
  
  // This call will apply our .hierarchyState to the new subnode.
  // If we are a managed hierarchy, as in ASCellNode trees, it will also apply our .interfaceState.
  [subnode _setSupernode:self];

  // If this subnode will be rasterized, update its hierarchy state & enter hierarchy if needed
  if (nodeIsInRasterizedTree(self)) {
    ASDisplayNodePerformBlockOnEveryNodeBFS(subnode, ^(ASDisplayNode * _Nonnull node) {
      [node enterHierarchyState:ASHierarchyStateRasterized];
      if (node.isNodeLoaded) {
        [node __unloadNode];
      }
    });
    if (self.isInHierarchy) {
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
  
  // Because the view and layer can only be created and destroyed on Main, that is also the only thread
  // where the view and layer can change. We can avoid locking.

  // If we can use view API, do. Due to an apple bug, -insertSubview:atIndex: actually wants a LAYER index,
  // which we pass in.
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
  
  ASDisplayNodeAssert(subnode, @"Cannot insert a nil subnode");
    
  // Don't add if it's already a subnode
  ASDisplayNode *oldParent = subnode.supernode;
  if (!subnode || subnode == self || oldParent == self) {
    return;
  }

  NSUInteger subnodesIndex;
  NSUInteger sublayersIndex;
  {
    ASDN::MutexLocker l(__instanceLock__);
    subnodesIndex = _subnodes.count;
    sublayersIndex = _layer.sublayers.count;
  }
  
  [self _insertSubnode:subnode atSubnodeIndex:subnodesIndex sublayerIndex:sublayersIndex andRemoveSubnode:nil];
}

- (void)_addSubnodeViewsAndLayers
{
  ASDisplayNodeAssertMainThread();
  
  TIME_SCOPED(_debugTimeToAddSubnodeViews);
  
  for (ASDisplayNode *node in self.subnodes) {
    [self _addSubnodeSubviewOrSublayer:node];
  }
}

- (void)_addSubnodeSubviewOrSublayer:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertMainThread();
  
  // Due to a bug in Apple's framework we have to use the layer index to insert a subview
  // so just use the count of the sublayers to add the subnode
  NSInteger idx = _layer.sublayers.count; // No locking is needed as it's main thread only
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

  if (replacementSubnode == nil) {
    ASDisplayNodeFailAssert(@"Invalid subnode to replace");
    return;
  }
  
  if (oldSubnode.supernode != self) {
    ASDisplayNodeFailAssert(@"Old Subnode to replace must be a subnode");
    return;
  }

  ASDisplayNodeAssert(!(self.nodeLoaded && !oldSubnode.nodeLoaded), @"We have view loaded, but child node does not.");

  NSInteger subnodeIndex;
  NSInteger sublayerIndex = NSNotFound;
  {
    ASDN::MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    subnodeIndex = [_subnodes indexOfObjectIdenticalTo:oldSubnode];
    
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

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (below.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert below must be a subnode");
    return;
  }

  NSInteger belowSubnodeIndex;
  NSInteger belowSublayerIndex = NSNotFound;
  {
    ASDN::MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    belowSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:below];
    
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

  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  if (above.supernode != self) {
    ASDisplayNodeFailAssert(@"Node to insert above must be a subnode");
    return;
  }

  NSInteger aboveSubnodeIndex;
  NSInteger aboveSublayerIndex = NSNotFound;
  {
    ASDN::MutexLocker l(__instanceLock__);
    ASDisplayNodeAssert(_subnodes, @"You should have subnodes if you have a subnode");
    
    aboveSubnodeIndex = [_subnodes indexOfObjectIdenticalTo:above];
    
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
  
  if (subnode == nil) {
    ASDisplayNodeFailAssert(@"Cannot insert a nil subnode");
    return;
  }

  NSInteger sublayerIndex = NSNotFound;
  {
    ASDN::MutexLocker l(__instanceLock__);
    
    if (idx > _subnodes.count || idx < 0) {
      ASDisplayNodeFailAssert(@"Cannot insert a subnode at index %zd. Count is %zd", idx, _subnodes.count);
      return;
    }
    
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
  }

  [self _insertSubnode:subnode atSubnodeIndex:idx sublayerIndex:sublayerIndex andRemoveSubnode:nil];
}

- (void)_removeSubnode:(ASDisplayNode *)subnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  // Don't call self.supernode here because that will retain/autorelease the supernode.  This method -_removeSupernode: is often called while tearing down a node hierarchy, and the supernode in question might be in the middle of its -dealloc.  The supernode is never messaged, only compared by value, so this is safe.
  // The particular issue that triggers this edge case is when a node calls -removeFromSupernode on a subnode from within its own -dealloc method.
  if (!subnode || subnode.supernode != self) {
    return;
  }

  __instanceLock__.lock();
    [_subnodes removeObjectIdenticalTo:subnode];
  __instanceLock__.unlock();

  [subnode _setSupernode:nil];
}

- (void)removeFromSupernode
{
  // TODO: 2.0 Conversion: Reenable and fix within product code
  //ASDisplayNodeAssert(self.supernode.automaticallyManagesSubnodes == NO, @"Attempt to manually remove subnode from node with automaticallyManagesSubnodes=YES. Node: %@", self);
    
  [self _removeFromSupernode];
}

- (void)_removeFromSupernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  __instanceLock__.lock();
    __weak ASDisplayNode *supernode = _supernode;
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
  __instanceLock__.unlock();

  [self _removeFromSupernode:supernode view:view layer:layer];
}

- (void)_removeFromSupernodeIfEqualTo:(ASDisplayNode *)supernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  __instanceLock__.lock();

    // Only remove if supernode is still the expected supernode
    if (!ASObjectIsEqual(_supernode, supernode)) {
      __instanceLock__.unlock();
      return;
    }
  
    __weak UIView *view = _view;
    __weak CALayer *layer = _layer;
  __instanceLock__.unlock();
  
  [self _removeFromSupernode:supernode view:view layer:layer];
}

- (void)_removeFromSupernode:(ASDisplayNode *)supernode view:(UIView *)view layer:(CALayer *)layer
{
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

#pragma mark - Visibility API

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
  __instanceLock__.lock();
  const size_t maxVisibilityIncrement = (1ULL<<VISIBILITY_NOTIFICATIONS_DISABLED_BITS) - 1ULL;
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled < maxVisibilityIncrement, @"Oops, too many increments of the visibility notifications API");
  if (_flags.visibilityNotificationsDisabled < maxVisibilityIncrement) {
    _flags.visibilityNotificationsDisabled++;
  }
  BOOL visibilityNotificationsDisabled = (_flags.visibilityNotificationsDisabled == 1);
  __instanceLock__.unlock();

  if (visibilityNotificationsDisabled) {
    // Must have just transitioned from 0 to 1.  Notify all subnodes that we are in a disabled state.
    [self enterHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

- (void)__decrementVisibilityNotificationsDisabled
{
  __instanceLock__.lock();
  ASDisplayNodeAssert(_flags.visibilityNotificationsDisabled > 0, @"Can't decrement past 0");
  if (_flags.visibilityNotificationsDisabled > 0) {
    _flags.visibilityNotificationsDisabled--;
  }
  BOOL visibilityNotificationsDisabled = (_flags.visibilityNotificationsDisabled == 0);
  __instanceLock__.unlock();

  if (visibilityNotificationsDisabled) {
    // Must have just transitioned from 1 to 0.  Notify all subnodes that we are no longer in a disabled state.
    // FIXME: This system should be revisited when refactoring and consolidating the implementation of the
    // addSubnode: and insertSubnode:... methods.  As implemented, though logically irrelevant for expected use cases,
    // multiple nodes in the subtree below may have a non-zero visibilityNotification count and still have
    // the ASHierarchyState bit cleared (the only value checked when reading this state).
    [self exitHierarchyState:ASHierarchyStateTransitioningSupernodes];
  }
}

#pragma mark - Placeholder

- (void)_locked_layoutPlaceholderIfNecessary
{
  if ([self _locked_shouldHavePlaceholderLayer]) {
    [self _locked_setupPlaceholderLayerIfNeeded];
  }
  // Update the placeholderLayer size in case the node size has changed since the placeholder was added.
  _placeholderLayer.frame = self.threadSafeBounds;
}

- (BOOL)_locked_shouldHavePlaceholderLayer
{
  return (_placeholderEnabled && [self _implementsDisplay]);
}

- (void)_locked_setupPlaceholderLayerIfNeeded
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

- (UIImage *)placeholderImage
{
  // Subclass hook
  return nil;
}

- (BOOL)placeholderShouldPersist
{
  // Subclass hook
  return NO;
}

#pragma mark - Hierarchy State

- (BOOL)isInHierarchy
{
  ASDN::MutexLocker l(__instanceLock__);
  return _flags.isInHierarchy;
}

- (void)__enterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"Should not cause recursive __enterHierarchy");
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  ASDisplayNodeLogEvent(self, @"enterHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  __instanceLock__.lock();
  
  if (!_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isEnteringHierarchy = YES;
    _flags.isInHierarchy = YES;

    // Don't call -willEnterHierarchy while holding __instanceLock__.
    // This method and subsequent ones (i.e -interfaceState and didEnter(.*)State)
    // don't expect that they are called while the lock is being held.
    // More importantly, didEnter(.*)State methods are meant to be overriden by clients.
    // And so they can potentially walk up the node tree and cause deadlocks, or do expensive tasks and cause the lock to be held for too long.
    __instanceLock__.unlock();
      [self willEnterHierarchy];
      for (ASDisplayNode *subnode in self.subnodes) {
        [subnode __enterHierarchy];
      }
    __instanceLock__.lock();
    
    _flags.isEnteringHierarchy = NO;

    // If we don't have contents finished drawing by the time we are on screen, immediately add the placeholder (if it is enabled and we do have something to draw).
    if (self.contents == nil) {
      CALayer *layer = self.layer;
      [layer setNeedsDisplay];
      
      if ([self _locked_shouldHavePlaceholderLayer]) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self _locked_setupPlaceholderLayerIfNeeded];
        _placeholderLayer.opacity = 1.0;
        [CATransaction commit];
        [layer addSublayer:_placeholderLayer];
      }
    }
  }
  
  __instanceLock__.unlock();
}

- (void)__exitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"Should not cause recursive __exitHierarchy");
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  ASDisplayNodeLogEvent(self, @"exitHierarchy");
  
  // Profiling has shown that locking this method is beneficial, so each of the property accesses don't have to lock and unlock.
  __instanceLock__.lock();
  
  if (_flags.isInHierarchy && !_flags.visibilityNotificationsDisabled && ![self __selfOrParentHasVisibilityNotificationsDisabled]) {
    _flags.isExitingHierarchy = YES;
    _flags.isInHierarchy = NO;

    [self._locked_asyncLayer cancelAsyncDisplay];

    // Don't call -didExitHierarchy while holding __instanceLock__.
    // This method and subsequent ones (i.e -interfaceState and didExit(.*)State)
    // don't expect that they are called while the lock is being held.
    // More importantly, didExit(.*)State methods are meant to be overriden by clients.
    // And so they can potentially walk up the node tree and cause deadlocks, or do expensive tasks and cause the lock to be held for too long.
    __instanceLock__.unlock();
      [self didExitHierarchy];
      for (ASDisplayNode *subnode in self.subnodes) {
        [subnode __exitHierarchy];
      }
    __instanceLock__.lock();
    
    _flags.isExitingHierarchy = NO;
  }
  
  __instanceLock__.unlock();
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
  
  // Entered or exited range managed state.
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
      ASDN::MutexLocker l(__instanceLock__);
      _pendingTransitionID = ASLayoutElementContextInvalidTransitionID;
      _pendingLayoutTransition = nil;
    }
  }

  ASDisplayNodeLogEvent(self, @"setHierarchyState: oldState = %@, newState = %@", NSStringFromASHierarchyState(oldState), NSStringFromASHierarchyState(newState));
}

- (void)willEnterHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isEnteringHierarchy, @"You should never call -willEnterHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isExitingHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateInHierarchy;
  }
}

- (void)didExitHierarchy
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isExitingHierarchy, @"You should never call -didExitHierarchy directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isEnteringHierarchy, @"ASDisplayNode inconsistency. __enterHierarchy and __exitHierarchy are mutually exclusive");
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  if (![self supportsRangeManagedInterfaceState]) {
    self.interfaceState = ASInterfaceStateNone;
  } else {
    // This case is important when tearing down hierarchies.  We must deliver a visibileStateDidChange:NO callback, as part our API guarantee that this method can be used for
    // things like data analytics about user content viewing.  We cannot call the method in the dealloc as any incidental retain operations in client code would fail.
    // Additionally, it may be that a Standard UIView which is containing us is moving between hierarchies, and we should not send the call if we will be re-added in the
    // same runloop.  Strategy: strong reference (might be the last!), wait one runloop, and confirm we are still outside the hierarchy (both layer-backed and view-backed).
    // TODO: This approach could be optimized by only performing the dispatch for root elements + recursively apply the interface state change. This would require a closer
    // integration with _ASDisplayLayer to ensure that the superlayer pointer has been cleared by this stage (to check if we are root or not), or a different delegate call.
    
    if (ASInterfaceStateIncludesVisible(self.interfaceState)) {
      dispatch_async(dispatch_get_main_queue(), ^{
        // This block intentionally retains self.
        __instanceLock__.lock();
          unsigned isInHierarchy = _flags.isInHierarchy;
          BOOL isVisible = ASInterfaceStateIncludesVisible(_interfaceState);
          ASInterfaceState newState = (_interfaceState & ~ASInterfaceStateVisible);
        __instanceLock__.unlock();
        
        if (!isInHierarchy && isVisible) {
          self.interfaceState = newState;
        }
      });
    }
  }
}

#pragma mark - Interface State

/**
 * We currently only set interface state on nodes in table/collection views. For other nodes, if they are
 * in the hierarchy we enable all ASInterfaceState types with `ASInterfaceStateInHierarchy`, otherwise `None`.
 */
- (BOOL)supportsRangeManagedInterfaceState
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASHierarchyStateIncludesRangeManaged(_hierarchyState);
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
  // This method manages __instanceLock__ itself, to ensure the lock is not held while didEnter/Exit(.*)State methods are called, thus avoid potential deadlocks
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  ASInterfaceState oldState = ASInterfaceStateNone;
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (_interfaceState == newState) {
      return;
    }
    oldState = _interfaceState;
    _interfaceState = newState;
  }

  // TODO: Trigger asynchronous measurement if it is not already cached or being calculated.
  // if ((newState & ASInterfaceStateMeasureLayout) != (oldState & ASInterfaceStateMeasureLayout)) {
  // }
  
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
        // Check _implementsDisplay purely for efficiency - it's faster even than calling -asyncLayer.
        if ([self _implementsDisplay]) {
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
  // Subclass hook
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate interfaceStateDidChange:newState fromState:oldState];
}

- (BOOL)shouldScheduleDisplayWithNewInterfaceState:(ASInterfaceState)newInterfaceState
{
  BOOL willDisplay = ASInterfaceStateIncludesDisplay(newInterfaceState);
  BOOL nowDisplay = ASInterfaceStateIncludesDisplay(self.interfaceState);
  return willDisplay && (willDisplay != nowDisplay);
}

- (BOOL)isVisible
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesVisible(_interfaceState);
}

- (void)didEnterVisibleState
{
  // subclass override
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didEnterVisibleState];
}

- (void)didExitVisibleState
{
  // subclass override
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didExitVisibleState];
}

- (BOOL)isInDisplayState
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesDisplay(_interfaceState);
}

- (void)didEnterDisplayState
{
  // subclass override
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didEnterDisplayState];
}

- (void)didExitDisplayState
{
  // subclass override
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didExitDisplayState];
}

- (BOOL)isInPreloadState
{
  ASDN::MutexLocker l(__instanceLock__);
  return ASInterfaceStateIncludesPreload(_interfaceState);
}

- (void)setNeedsPreload
{
  if (self.isInPreloadState) {
    [self recursivelyPreload];
  }
}

- (void)recursivelyPreload
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node didEnterPreloadState];
    });
  });
}

- (void)recursivelyClearPreloadedData
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node didExitPreloadState];
    });
  });
}

- (void)didEnterPreloadState
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didEnterPreloadState];
  
  // Trigger a layout pass to ensure all subnodes have the correct size to preload their content.
  // This is important for image nodes, as well as collection and table nodes.
  [self layoutIfNeeded];
  
  if (_methodOverrides & ASDisplayNodeMethodOverrideFetchData) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self fetchData];
#pragma clang diagnostic pop
  }
}

- (void)didExitPreloadState
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  [_interfaceStateDelegate didExitPreloadState];
  
  if (_methodOverrides & ASDisplayNodeMethodOverrideClearFetchedData) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [self clearFetchedData];
#pragma clang diagnostic pop
  }
}

- (void)clearContents
{
  ASDisplayNodeAssertMainThread();
  if (_flags.canClearContentsOfLayer) {
    // No-op if these haven't been created yet, as that guarantees they don't have contents that needs to be released.
    _layer.contents = nil;
  }
  
  _placeholderLayer.contents = nil;
  _placeholderImage = nil;
}

- (void)recursivelyClearContents
{
  ASPerformBlockOnMainThread(^{
    ASDisplayNodePerformBlockOnEveryNode(nil, self, YES, ^(ASDisplayNode * _Nonnull node) {
      [node clearContents];
    });
  });
}



#pragma mark - Gesture Recognizing

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  // Subclass hook
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  // This method is only implemented on UIView on iOS 6+.
  ASDisplayNodeAssertMainThread();
  
  // No locking needed as it's main thread only
  UIView *view = _view;
  if (view == nil) {
    return YES;
  }

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = view.superview;
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

- (void)_locked_applyPendingStateToViewOrLayer
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(self.nodeLoaded, @"must have a view or layer");

  TIME_SCOPED(_debugTimeToApplyPendingState);
  
  // If no view/layer properties were set before the view/layer were created, _pendingViewState will be nil and the default values
  // for the view/layer are still valid.
  [self _locked_applyPendingViewState];
  
  if (_flags.displaySuspended) {
    self._locked_asyncLayer.displaySuspended = YES;
  }
  if (!_flags.displaysAsynchronously) {
    self._locked_asyncLayer.displaysAsynchronously = NO;
  }
}

- (void)applyPendingViewState
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssertLockUnownedByCurrentThread(__instanceLock__);
  
  ASDN::MutexLocker l(__instanceLock__);
  // FIXME: Ideally we'd call this as soon as the node receives -setNeedsLayout
  // but automatic subnode management would require us to modify the node tree
  // in the background on a loaded node, which isn't currently supported.
  if (_pendingViewState.hasSetNeedsLayout) {
    // Need to unlock before calling setNeedsLayout to avoid deadlocks.
    // MutexUnlocker will re-lock at the end of scope.
    ASDN::MutexUnlocker u(__instanceLock__);
    [self __setNeedsLayout];
  }
  
  [self _locked_applyPendingViewState];
}

- (void)_locked_applyPendingViewState
{
  ASDisplayNodeAssertMainThread();

  if (_flags.layerBacked) {
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

#pragma mark - Performance Measurement

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


#pragma mark - Debugging (Private)

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
  
  // Attempt to find view controller.
  // Note that the convenience method asdk_associatedViewController has an assertion
  // that it's run on main. Since this is a debug method, let's bypass the assertion
  // and run up the chain ourselves.
  if (_view != nil) {
    for (UIResponder *responder in [_view asdk_responderChainEnumerator]) {
      UIViewController *vc = ASDynamicCast(responder, UIViewController);
      if (vc) {
        [result addObject:@{ @"viewController" : ASObjectDescriptionMakeTiny(vc) }];
        break;
      }
    }
  }
  
  if (_view != nil) {
    [result addObject:@{ @"alpha" : @(_view.alpha) }];
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_view.frame] }];
  } else if (_layer != nil) {
    [result addObject:@{ @"alpha" : @(_layer.opacity) }];
    [result addObject:@{ @"frame" : [NSValue valueWithCGRect:_layer.frame] }];
  } else if (_pendingViewState != nil) {
    [result addObject:@{ @"alpha" : @(_pendingViewState.alpha) }];
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

#if TIME_DISPLAYNODE_OPS
  NSString *creationTypeString = [NSString stringWithFormat:@"cr8:%.2lfms dl:%.2lfms ap:%.2lfms ad:%.2lfms",  1000 * _debugTimeToCreateView, 1000 * _debugTimeForDidLoad, 1000 * _debugTimeToApplyPendingState, 1000 * _debugTimeToAddSubnodeViews];
  [result addObject:@{ @"creationTypeString" : creationTypeString }];
#endif
  
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
    CALayer *nextLayer = nil;
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

#pragma mark - ASPrimitiveTraitCollection

- (ASPrimitiveTraitCollection)primitiveTraitCollection
{
  ASDN::MutexLocker l(__instanceLock__);
  return _primitiveTraitCollection;
}

- (void)setPrimitiveTraitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  __instanceLock__.lock();
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(traitCollection, _primitiveTraitCollection) == NO) {
    _primitiveTraitCollection = traitCollection;
    ASDisplayNodeLogEvent(self, @"asyncTraitCollectionDidChange: %@", NSStringFromASPrimitiveTraitCollection(traitCollection));
    __instanceLock__.unlock();
    
    [self asyncTraitCollectionDidChange];
    return;
  }
  
  __instanceLock__.unlock();
}

- (ASTraitCollection *)asyncTraitCollection
{
  ASDN::MutexLocker l(__instanceLock__);
  return [ASTraitCollection traitCollectionWithASPrimitiveTraitCollection:self.primitiveTraitCollection];
}

- (void)asyncTraitCollectionDidChange
{
  // Subclass override
}

ASPrimitiveTraitCollectionDeprecatedImplementation

#pragma mark - ASLayoutElementStyleExtensibility

ASLayoutElementStyleExtensibilityForwarding

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

// This methods cannot be moved into the category ASDisplayNode (Deprecated). So they need to be declared in ASDisplayNode until removed

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
  return [self layoutThatFits:constrainedSize parentSize:constrainedSize.max];
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

#pragma mark - ASDisplayNode (Debugging)

@implementation ASDisplayNode (Debugging)

- (NSString *)displayNodeRecursiveDescription
{
  return [self _recursiveDescriptionHelperWithIndent:@""];
}

- (NSString *)_recursiveDescriptionHelperWithIndent:(NSString *)indent
{
  NSMutableString *subtree = [[[indent stringByAppendingString:self.debugDescription] stringByAppendingString:@"\n"] mutableCopy];
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

#pragma mark - ASDisplayNode UIKit / CA Categories

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
      if (subnode.supernode) {
        [subnode removeFromSupernode];
      }
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
    if (subnode.supernode) {
      [subnode removeFromSupernode];
    }
    [self addSublayer:subnode.layer];
  }
}

@end

#pragma mark - ASDisplayNode (Deprecated)

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

@end
