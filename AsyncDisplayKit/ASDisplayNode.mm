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

#import <objc/runtime.h>

#import "_ASAsyncTransaction.h"
#import "_ASPendingState.h"
#import "_ASDisplayView.h"
#import "_ASScopeTimer.h"
#import "ASDisplayNodeExtras.h"

@interface ASDisplayNode () <UIGestureRecognizerDelegate>

/**
 *
 * See ASDisplayNodeInternal.h for ivars
 *
 */

@end

// Conditionally time these scopes to our debug ivars (only exist in debug/profile builds)
#if TIME_DISPLAYNODE_OPS
#define TIME_SCOPED(outVar) ASDN::ScopeTimer t(outVar)
#else
#define TIME_SCOPED(outVar)
#endif

@implementation ASDisplayNode

BOOL ASDisplayNodeSubclassOverridesSelector(Class subclass, SEL selector)
{
  Method superclassMethod = class_getInstanceMethod([ASDisplayNode class], selector);
  Method subclassMethod = class_getInstanceMethod(subclass, selector);
  IMP superclassIMP = superclassMethod ? method_getImplementation(superclassMethod) : NULL;
  IMP subclassIMP = subclassMethod ? method_getImplementation(subclassMethod) : NULL;

  return (superclassIMP != subclassIMP);
}

+ (void)initialize
{
  if (self == [ASDisplayNode class]) {
    return;
  }

  // Subclasses should never override these
  ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(calculatedSize)), @"Subclass %@ must not override calculatedSize method", NSStringFromClass(self));
  ASDisplayNodeAssert(!ASDisplayNodeSubclassOverridesSelector(self, @selector(sizeToFit:)), @"Subclass %@ must not override sizeToFit method", NSStringFromClass(self));
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

#pragma mark - NSObject Overrides

- (id)initWithViewClass:(Class)viewClass
{
  if (!(self = [self init]))
    return nil;

  ASDisplayNodeAssert([viewClass isSubclassOfClass:[UIView class]], @"should initialize with a subclass of UIView");
  _viewClass = [viewClass retain];
  _flags.isSynchronous = ![viewClass isSubclassOfClass:[_ASDisplayView class]];

  return self;
}

- (id)initWithLayerClass:(Class)layerClass
{
  if (!(self = [self init]))
    return nil;

  ASDisplayNodeAssert([layerClass isSubclassOfClass:[CALayer class]], @"should initialize with a subclass of CALayer");

  _layerClass = [layerClass retain];
  _flags.isSynchronous = ![layerClass isSubclassOfClass:[_ASDisplayLayer class]];

  _flags.isLayerBacked = YES;

  return self;
}

- (id)init
{
  self = [super init];
  if (!self) return nil;

  _contentsScaleForDisplay = [[UIScreen mainScreen] scale];

  _displaySentinel = [[ASSentinel alloc] init];

  _flags.inWindow = NO;
  _flags.displaysAsynchronously = YES;

  _flags.implementsDisplay = [[self class] respondsToSelector:@selector(drawRect:withParameters:isCancelled:isRasterizing:)] || [self.class respondsToSelector:@selector(displayWithParameters:isCancelled:)];

  _flags.hasWillDisplayAsyncLayer = ([self respondsToSelector:@selector(willDisplayAsyncLayer:)] ? 1 : 0);
  _flags.hasClassDisplay = ([[self class] respondsToSelector:@selector(displayWithParameters:isCancelled:)] ? 1 : 0);
  _flags.hasDrawParametersForAsyncLayer = ([self respondsToSelector:@selector(drawParametersForAsyncLayer:)] ? 1 : 0);

  return self;
}

#if __has_feature(objc_arc)
#warning This file must be compiled without ARC. Use -fno-objc-arc (or convert project to MRR).
#endif

#if !__has_feature(objc_arc)
_OBJC_SUPPORTED_INLINE_REFCNT_WITH_DEALLOC2MAIN(_retainCount);
#endif

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

  [_viewClass release];
  [_subnodes release];

  [_view release];
  _view = nil;
  _subnodes = nil;
  if (_flags.isLayerBacked) {
    _layer.delegate = nil;
  }
  [_layer release];
  _layer = nil;

  [self __setSupernode:nil];
  [_pendingViewState release];
  _pendingViewState = nil;
  [_replaceAsyncSentinel release];
  _replaceAsyncSentinel = nil;

  [_displaySentinel release];
  _displaySentinel = nil;

  [super dealloc];
}

#pragma mark - UIResponder overrides

- (UIResponder *)nextResponder
{
  return self.view.superview;
}

#pragma mark - Core

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
    if (!_layerClass) {
      _layerClass = [self.class layerClass];
    }

    _layer = [[_layerClass alloc] init];
    _layer.delegate = self;
  } else {
    TIME_SCOPED(_debugTimeToCreateView);
    if (!_viewClass) {
      _viewClass = [self.class viewClass];
    }
    _view = [[_viewClass alloc] init];
    _view.asyncdisplaykit_node = self;
    _layer = [_view.layer retain];
  }
  _layer.asyncdisplaykit_node = self;
#if DEBUG
  _layer.name = self.description;
#endif
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
    [self didLoad];
  }
}

- (UIView *)view
{
  ASDisplayNodeAssert(!_flags.isLayerBacked, @"Call to -view undefined on layer-backed nodes");
  if (_flags.isLayerBacked) {
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

    if (!_flags.isLayerBacked) {
      return self.view.layer;
    }
    [self _loadViewOrLayerIsLayerBacked:YES];
  }
  return _layer;
}

// Returns nil if our view is not an _ASDisplayView, but will create it if necessary.
- (_ASDisplayView *)ensureAsyncView
{
  return _flags.isSynchronous ? nil:(_ASDisplayView *)self.view;
}

// Returns nil if the layer is not an _ASDisplayLayer; will not create the view if nil
- (_ASDisplayLayer *)asyncLayer
{
  ASDN::MutexLocker l(_propertyLock);
  return [_layer isKindOfClass:[_ASDisplayLayer class]] ? (_ASDisplayLayer *)_layer : nil;
}

- (BOOL)isViewLoaded
{
  ASDN::MutexLocker l(_propertyLock);
  return (_view != nil || (_flags.isLayerBacked && _layer != nil));
}

- (BOOL)isSynchronous
{
  return _flags.isSynchronous;
}

- (void)setIsSynchronous:(BOOL)flag
{
  _flags.isSynchronous = flag;
}

- (void)setIsLayerBacked:(BOOL)isLayerBacked
{
  if (![self.class layerBackedNodesEnabled]) return;

  ASDN::MutexLocker l(_propertyLock);
  ASDisplayNodeAssert(!_view && !_layer, @"Cannot change isLayerBacked after layer or view has loaded");
  if (isLayerBacked != _flags.isLayerBacked && !_view && !_layer) {
    _flags.isLayerBacked = isLayerBacked;
  }
}

- (BOOL)isLayerBacked
{
  ASDN::MutexLocker l(_propertyLock);
  return _flags.isLayerBacked;
}

#pragma mark -

- (CGSize)sizeToFit:(CGSize)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);

  if (![self __shouldSize])
    return CGSizeZero;

  // only calculate the size if
  //  - we haven't already
  //  - the width is different from the last time
  //  - the height is different from the last time
  if (!_flags.sizeCalculated || !CGSizeEqualToSize(constrainedSize, _constrainedSize)) {
    _size = [self calculateSizeThatFits:constrainedSize];
    _constrainedSize = constrainedSize;
    _flags.sizeCalculated = YES;
  }

  ASDisplayNodeAssertTrue(_size.width >= 0.0);
  ASDisplayNodeAssertTrue(_size.height >= 0.0);
  return _size;
}

- (BOOL)displaysAsynchronously
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
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
  if (_flags.isSynchronous)
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
  ASDisplayNodeAssert(!_flags.isSynchronous, @"this method is designed for asynchronous mode only");

  [[self asyncLayer] displayImmediately];
}

// These private methods ensure that subclasses are not required to call super in order for _renderingSubnodes to be properly managed.

- (void)__layout
{
  ASDisplayNodeAssertMainThread();
  ASDN::MutexLocker l(_propertyLock);
  if (CGRectEqualToRect(_layer.bounds, CGRectZero))
    return;     // Performing layout on a zero-bounds view often results in frame calculations with negative sizes after applying margins, which will cause sizeToFit: on subnodes to assert.
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
  CATransform3D nodeTransform = _calculateTransformFromReferenceToTarget(self, node);
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
    [self __appear];
  } else if (event == kCAOnOrderOut) {
    [self __disappear];
  }

  ASDisplayNodeAssert(_flags.isLayerBacked, @"We shouldn't get called back here if there is no layer");
  return (id<CAAction>)[NSNull null];
}

#pragma mark -

static bool disableNotificationsForMovingBetweenParents(ASDisplayNode *from, ASDisplayNode *to)
{
  if (!from || !to) return NO;
  if (from->_flags.isSynchronous) return NO;
  if (to->_flags.isSynchronous) return NO;
  if (from->_flags.inWindow != to->_flags.inWindow) return NO;
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

  if (self.isViewLoaded) {
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

  [subnode retain];

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
          [_layer insertSublayer:subnode.layer atIndex:sublayerIndex];
        }
      }
    }
  }

  ASDisplayNodeAssert(isMovingEquivalentParents == disableNotificationsForMovingBetweenParents(oldParent, self), @"Invariant violated");
  if (isMovingEquivalentParents) {
    [subnode __decrementVisibilityNotificationsDisabled];
  }

  [subnode __setSupernode:self];
  [subnode release];
}

- (void)replaceSubnode:(ASDisplayNode *)oldSubnode withSubnode:(ASDisplayNode *)replacementSubnode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);

  if (!replacementSubnode || [oldSubnode _deallocSafeSupernode] != self) {
    ASDisplayNodeAssert(0, @"Bad use of api. Invalid subnode to replace async.");
    return;
  }

  ASDisplayNodeAssert(!(self.isViewLoaded && !oldSubnode.isViewLoaded), @"ASDisplayNode corruption bug. We have view loaded, but child node does not.");
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
    NSString *reason = [NSString stringWithFormat:@"Cannot insert a subnode at index %d. Count is %d", idx, _subnodes.count];
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
  ASDisplayNodeAssert(self.isViewLoaded, @"_addSubnodeSubview: should never be called before our own view is created");

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

  for (ASDisplayNode *node in [[_subnodes copy] autorelease]) {
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
    if (_flags.isLayerBacked) {
      [_layer removeFromSuperlayer];
    } else {
      [_view removeFromSuperview];
    }
  } else {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (_flags.isLayerBacked) {
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
  const size_t maxVisibilityIncrement = (1ULL<<visibilityNotificationsDisabledBits) - 1ULL;
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

- (void)__appear
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isInAppear, @"Should not cause recursive __appear");
  if (!self.inWindow && !_flags.visibilityNotificationsDisabled && ![self __hasParentWithVisibilityNotificationsDisabled]) {
    self.inWindow = YES;
    _flags.isInAppear = YES;
    if (self.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveWillAppear];
    } else {
      [self willAppear];
    }
    _flags.isInAppear = NO;
  }
}

- (void)__disappear
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(!_flags.isInDisappear, @"Should not cause recursive __disappear");
  if (self.inWindow && !_flags.visibilityNotificationsDisabled && ![self __hasParentWithVisibilityNotificationsDisabled]) {
    self.inWindow = NO;

    [self.asyncLayer cancelAsyncDisplay];

    _flags.isInDisappear = YES;
    if (self.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveWillDisappear];
    } else {
      [self willDisappear];
    }

    if (self.shouldRasterizeDescendants) {
      // Nodes that are descendants of a rasterized container do not have views or layers, and so cannot receive visibility notifications directly via orderIn/orderOut CALayer actions.  Manually send visibility notifications to rasterized descendants.
      [self _recursiveDidDisappear];
    } else {
      [self didDisappear];
    }

    _flags.isInDisappear = NO;
  }
}

- (void)_recursiveWillAppear
{
  if (_flags.visibilityNotificationsDisabled) {
    return;
  }

  _flags.isInAppear = YES;
  [self willAppear];
  _flags.isInAppear = NO;

  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursiveWillAppear];
  }
}

- (void)_recursiveWillDisappear
{
  if (_flags.visibilityNotificationsDisabled) {
    return;
  }

  _flags.isInDisappear = YES;
  [self willDisappear];
  _flags.isInDisappear = NO;

  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursiveWillDisappear];
  }
}

- (void)_recursiveDidDisappear
{
  if (_flags.visibilityNotificationsDisabled) {
    return;
  }

  _flags.isInDisappear = YES;
  [self didDisappear];
  _flags.isInDisappear = NO;

  for (ASDisplayNode *subnode in self.subnodes) {
    [subnode _recursiveDidDisappear];
  }
}

- (NSArray *)subnodes
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return [[_subnodes copy] autorelease];
}

- (ASDisplayNode *)supernode
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return [[_supernode retain] autorelease];
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

#pragma mark - For Subclasses

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return CGSizeZero;
}

- (CGSize)calculatedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _size;
}

- (CGSize)constrainedSizeForCalulatedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  return _constrainedSize;
}

- (void)invalidateCalculatedSize
{
  ASDisplayNodeAssertThreadAffinity(self);
  // This will cause -sizeToFit: to actually compute the size instead of returning the previously cached size
  _flags.sizeCalculated = NO;
}

- (void)didLoad
{
  ASDisplayNodeAssertMainThread();
}

- (void)willAppear
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isInAppear, @"You should never call -willAppear directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isInDisappear, @"ASDisplayNode inconsistency. __appear and __disappear are mutually exclusive");
}

- (void)willDisappear
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isInDisappear, @"You should never call -willDisappear directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isInAppear, @"ASDisplayNode inconsistency. __appear and __disappear are mutually exclusive");
}

- (void)didDisappear
{
  ASDisplayNodeAssertMainThread();
  ASDisplayNodeAssert(_flags.isInDisappear, @"You should never call -didDisappear directly. Appearance is automatically managed by ASDisplayNode");
  ASDisplayNodeAssert(!_flags.isInAppear, @"ASDisplayNode inconsistency. __appear and __disappear are mutually exclusive");
}

- (void)layout
{
  ASDisplayNodeAssertMainThread();
}

- (void)displayDidFinish
{
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
  ASDisplayNodeAssertMainThread();

  if (!_view)
    return;

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = _view.superview;
  [superview touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();

  if (!_view)
    return;

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = _view.superview;
  [superview touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();

  if (!_view)
    return;

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = _view.superview;
  [superview touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  ASDisplayNodeAssertMainThread();

  if (!_view)
    return;

  // If we reach the base implementation, forward up the view hierarchy.
  UIView *superview = _view.superview;
  [superview touchesCancelled:touches withEvent:event];
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
  ASDisplayNodeAssert(self.isViewLoaded, @"must have a view or layer");

  // If no view/layer properties were set before the view/layer were created, _pendingViewState will be nil and the default values
  // for the view/layer are still valid.
  ASDN::MutexLocker l(_propertyLock);

  if (_flags.isLayerBacked) {
    [_pendingViewState applyToLayer:_layer];
  } else {
    [_pendingViewState applyToView:_view];
  }

  [_pendingViewState release];
  _pendingViewState = nil;

  // TODO: move this into real pending state
  if (_flags.preventOrCancelDisplay) {
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

- (void)recursiveSetPreventOrCancelDisplay:(BOOL)flag
{
  _recursiveSetPreventOrCancelDisplay(self, nil, flag);
}

static void _recursiveSetPreventOrCancelDisplay(ASDisplayNode *node, CALayer *layer, BOOL flag)
{
  // If there is no layer, but node whose its view is loaded, then we can traverse down its layer hierarchy.  Otherwise we must stick to the node hierarchy to avoid loading views prematurely.  Note that for nodes that haven't loaded their views, they can't possibly have subviews/sublayers, so we don't need to traverse the layer hierarchy for them.
  if (!layer && node && node.isViewLoaded) {
    layer = node.layer;
  }

  // If we don't know the node, but the layer is an async layer, get the node from the layer.
  if (!node && layer && [layer isKindOfClass:[_ASDisplayLayer class]]) {
    node = layer.asyncdisplaykit_node;
  }

  // Set the flag on the node.  If this is a pure layer (no node) then this has no effect (plain layers don't support preventing/cancelling display).
  node.preventOrCancelDisplay = flag;

  if (layer) {
    // If there is a layer, recurse down the layer hierarchy to set the flag on descendants.  This will cover both layer-based and node-based children.
    for (CALayer *sublayer in layer.sublayers) {
      _recursiveSetPreventOrCancelDisplay(nil, sublayer, flag);
    }
  } else {
    // If there is no layer (view not loaded yet), recurse down the subnode hierarchy to set the flag on descendants.  This covers only node-based children, but for a node whose view is not loaded it can't possibly have nodeless children.
    for (ASDisplayNode *subnode in node.subnodes) {
      _recursiveSetPreventOrCancelDisplay(subnode, nil, flag);
    }
  }
}

- (BOOL)preventOrCancelDisplay
{
  ASDisplayNodeAssertThreadAffinity(self);
  ASDN::MutexLocker l(_propertyLock);
  return _flags.preventOrCancelDisplay;
}

- (void)setPreventOrCancelDisplay:(BOOL)flag
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Can't do this for synchronous nodes (using layers that are not _ASDisplayLayer and so we can't control display prevention/cancel)
  if (_flags.isSynchronous)
    return;

  ASDN::MutexLocker l(_propertyLock);

  if (_flags.preventOrCancelDisplay == flag)
    return;

  _flags.preventOrCancelDisplay = flag;

  self.asyncLayer.displaySuspended = flag;
}

- (BOOL)isInWindow
{
  ASDisplayNodeAssertThreadAffinity(self);

  ASDN::MutexLocker l(_propertyLock);
  return _flags.inWindow;
}

- (void)setInWindow:(BOOL)inWindow
{
  ASDisplayNodeAssertThreadAffinity(self);

  ASDN::MutexLocker l(_propertyLock);
  _flags.inWindow = inWindow;
}

+ (dispatch_queue_t)asyncSizingQueue
{
  static dispatch_queue_t asyncSizingQueue = NULL;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    asyncSizingQueue = dispatch_queue_create("com.facebook.AsyncDisplayKit.ASDisplayNode.asyncSizingQueue", DISPATCH_QUEUE_CONCURRENT);
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
  return [[_replaceAsyncSentinel retain] autorelease];
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

    [self sizeToFit:bounds.size];

    // Check sentinel after, bail early
    if (sentinel.value != sentinelValue)
      return dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });

    // Success; not cancelled
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(self);
    });
  });

}

- (void)replaceSubnodeAsynchronously:(ASDisplayNode *)old withNode:(ASDisplayNode *)replacement completion:(void(^)(BOOL cancelled, ASDisplayNode *replacement, ASDisplayNode *oldSubnode))completion
{

  ASDisplayNodeAssert(old.supernode == self, @"Must replace something that is actually a subnode. You passed: %@", old);
  ASDisplayNodeAssert(!replacement.isViewLoaded, @"Can't async size something that already has a view, since we currently have no way to convert a viewed node into a viewless one...");

  // If we're already marked for replacement, cancel the pending request
  ASSentinel *sentinel = [old _asyncReplaceSentinel];
  uint32_t sentinelValue = [sentinel increment];

  // Enqueue async sizing on our argument
  [replacement _enqueueAsyncSizingWithSentinel:sentinel completion:^(ASDisplayNode *replacementCompletedNode) {
    // Sizing is done; swap with our other view
    // Check sentinel one more time in case it changed during sizing
    if (replacementCompletedNode && sentinel.value == sentinelValue) {
      if (old.supernode) {
        if (old.supernode.inWindow) {
          // Now wait for async display before notifying delegate that replacement is complete

          // When async sizing is complete, add subnode below placeholder with 0 alpha
          CGFloat replacementAlpha = replacement.alpha;
          BOOL wasAsyncTransactionContainer = replacement.asyncdisplaykit_asyncTransactionContainer;
          [old.supernode insertSubnode:replacement belowSubnode:old];

          replacementCompletedNode.alpha = 0.0;
          replacementCompletedNode.asyncdisplaykit_asyncTransactionContainer = YES;

          ASDisplayNodeCAssert(replacementCompletedNode.isViewLoaded, @".layer shouldn't be the thing to load the view");

          [replacement.layer.asyncdisplaykit_asyncTransaction addCompletionBlock:^(id<NSObject> unused, BOOL canceled) {
            ASDisplayNodeCAssertMainThread();

            canceled |= (sentinel.value != sentinelValue);

            replacementCompletedNode.alpha = replacementAlpha;
            replacementCompletedNode.asyncdisplaykit_asyncTransactionContainer = wasAsyncTransactionContainer;

            if (!canceled) {
              [old removeFromSupernode];
            } else {
              [replacementCompletedNode removeFromSupernode];
            }

            completion(canceled, replacementCompletedNode, old);
          }];
        } else {
          // Not in window, don't wait for async display
          [old.supernode replaceSubnode:old withSubnode:replacement];
          completion(NO, replacementCompletedNode, old);
        }

      } else { // Old has been moved no longer to be in the hierarchy
        // TODO: add code to removeFromSupernode and hook UIView methods to cancel sentinel here?
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Tried to replaceSubnodeAsynchronously an ASDisplayNode, but then removed it from the hierarchy... what did you mean?" userInfo:nil];

        completion(NO, replacementCompletedNode, old);
      }
    } else { // If we were cancelled
      completion(YES, nil, nil);
    }
  }];


}

- (ASDisplayNode *)addSubnodeAsynchronously:(ASDisplayNode *)replacement completion:(void(^)(ASDisplayNode *fullySizedSubnode))completion
{
  ASDisplayNodeAssertThreadAffinity(self);

  // Create a placeholder ASDisplayNode that saves this guy's place in the view hierarchy for when things return later
  ASDisplayNode *placeholder = [[ASDisplayNode alloc] init];

  [self addSubnode:placeholder];
  [self replaceSubnodeAsynchronously:placeholder withNode:replacement completion:^(BOOL cancelled, ASDisplayNode *replacementBlock, ASDisplayNode *placeholderBlock) {
    if (replacementBlock && placeholderBlock && !cancelled) {
      [placeholderBlock removeFromSupernode];
      completion(replacementBlock);
    } else {
      [placeholderBlock removeFromSupernode];
    }
  }];

  return [placeholder autorelease];
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
  NSString *notableTargetDesc = (_flags.isLayerBacked ? @" [layer]" : @" [view]");
  if (_view && _viewClass) { // Nonstandard view is loaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@ : %p]", _view.class, _view];
  } else if (_layer && _layerClass) { // Nonstandard layer is loaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@ : %p]", _layer.class, _layer];
  } else if (_viewClass) { // Nonstandard view class unloaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@]", _viewClass];
  } else if (_layerClass) { // Nonstandard layer class unloaded
    notableTargetDesc = [NSString stringWithFormat:@" [%@]", _layerClass];
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
  NSMutableString *subtree = [[[[indent stringByAppendingString: self.descriptionForRecursiveDescription] stringByAppendingString:@"\n"] mutableCopy] autorelease];
  for (ASDisplayNode *n in self.subnodes) {
    [subtree appendString:[n _recursiveDescriptionHelperWithIndent:[indent stringByAppendingString:@" | "]]];
  }
  return subtree;
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
