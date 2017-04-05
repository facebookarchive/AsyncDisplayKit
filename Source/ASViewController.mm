//
//  ASViewController.mm
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/ASViewController.h>
#import <AsyncDisplayKit/ASAssert.h>
#import <AsyncDisplayKit/ASDisplayNode+FrameworkPrivate.h>
#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASTraitCollection.h>
#import <AsyncDisplayKit/ASRangeControllerUpdateRangeProtocol+Beta.h>
#import <AsyncDisplayKit/ASInternalHelpers.h>

#define AS_LOG_VISIBILITY_CHANGES 0

@implementation ASViewController
{
  BOOL _ensureDisplayed;
  BOOL _automaticallyAdjustRangeModeBasedOnViewEvents;
  BOOL _parentManagesVisibilityDepth;
  NSInteger _visibilityDepth;
  BOOL _selfConformsToRangeModeProtocol;
  BOOL _nodeConformsToRangeModeProtocol;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    return nil;
  }
  
  [self _initializeInstance];
  
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  if (!(self = [super initWithCoder:aDecoder])) {
    return nil;
  }
  
  [self _initializeInstance];
  
  return self;
}

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (!(self = [super initWithNibName:nil bundle:nil])) {
    return nil;
  }
  
  _node = node;
  [self _initializeInstance];

  return self;
}

- (void)_initializeInstance
{
  if (_node == nil) {
    return;
  }
  
  _selfConformsToRangeModeProtocol = [self conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _nodeConformsToRangeModeProtocol = [_node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _automaticallyAdjustRangeModeBasedOnViewEvents = _selfConformsToRangeModeProtocol || _nodeConformsToRangeModeProtocol;
  
  // In case the node will get loaded
  if (_node.nodeLoaded) {
    // Node already loaded the view
    [self view];
  } else {
    // If the node didn't load yet add ourselves as on did load observer to load the view in case the node gets loaded
    // before the view controller
    __weak __typeof__(self) weakSelf = self;
    [_node onDidLoad:^(__kindof ASDisplayNode * _Nonnull node) {
      if ([weakSelf isViewLoaded] == NO) {
        [weakSelf view];
      }
    }];
  }
}

- (void)dealloc
{
  ASPerformBackgroundDeallocation(_node);
}

- (void)loadView
{
  // Apple applies a frame and autoresizing masks we need.  Allocating a view is not
  // nearly as expensive as adding and removing it from a hierarchy, and fortunately
  // we can avoid that here.  Enabling layerBacking on a single node in the hierarchy
  // will have a greater performance benefit than the impact of this transient view.
  [super loadView];
  
  if (_node == nil) {
    return;
  }
  
  ASDisplayNodeAssertTrue(!_node.layerBacked);
  
  UIView *view = self.view;
  CGRect frame = view.frame;
  UIViewAutoresizing autoresizingMask = view.autoresizingMask;
  
  // We have what we need, so now create and assign the view we actually want.
  view = _node.view;
  _node.frame = frame;
  _node.autoresizingMask = autoresizingMask;
  self.view = view;
  
  // ensure that self.node has a valid trait collection before a subclass's implementation of viewDidLoad.
  // Any subnodes added in viewDidLoad will then inherit the proper environment.
  ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
  [self propagateNewTraitCollection:traitCollection];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  // Before layout, make sure that our trait collection containerSize actually matches the size of our bounds.
  // If not, we need to update the traits and propagate them.

  CGSize boundsSize = self.view.bounds.size;
  if (CGSizeEqualToSize(self.node.primitiveTraitCollection.containerSize, boundsSize) == NO) {
    [UIView performWithoutAnimation:^{
      ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
      traitCollection.containerSize = boundsSize;
        
      // this method will call measure
      [self propagateNewTraitCollection:traitCollection];
    }];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Call layoutThatFits: to let the node prepare for a layout that will happen shortly in the layout pass of the view.
    // If the node's constrained size didn't change between the last layout pass it's a no-op
    [_node layoutThatFits:[self nodeConstrainedSize]];
#pragma clang diagnostic pop
  }
}

- (void)viewDidLayoutSubviews
{
  if (_ensureDisplayed && self.neverShowPlaceholders) {
    _ensureDisplayed = NO;
    [_node recursivelyEnsureDisplaySynchronously:YES];
  }
  [super viewDidLayoutSubviews];
}

ASVisibilityDidMoveToParentViewController;

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  _ensureDisplayed = YES;

  // A layout pass is forced this early to get nodes like ASCollectionNode, ASTableNode etc.
  // into the hierarchy before UIKit applies the scroll view inset adjustments, if automatic subnode management
  // is enabled. Otherwise the insets would not be applied.
  [_node.view layoutIfNeeded];
  
  if (_parentManagesVisibilityDepth == NO) {
    [self setVisibilityDepth:0];
  }
}

ASVisibilitySetVisibilityDepth;

ASVisibilityViewDidDisappearImplementation;

ASVisibilityDepthImplementation;

- (void)visibilityDepthDidChange
{
  ASLayoutRangeMode rangeMode = ASLayoutRangeModeForVisibilityDepth(self.visibilityDepth);
#if AS_LOG_VISIBILITY_CHANGES
  NSString *rangeModeString;
  switch (rangeMode) {
    case ASLayoutRangeModeMinimum:
      rangeModeString = @"Minimum";
      break;
      
    case ASLayoutRangeModeFull:
      rangeModeString = @"Full";
      break;
      
    case ASLayoutRangeModeVisibleOnly:
      rangeModeString = @"Visible Only";
      break;
      
    case ASLayoutRangeModeLowMemory:
      rangeModeString = @"Low Memory";
      break;
      
    default:
      break;
  }
  NSLog(@"Updating visibility of:%@ to: %@ (visibility depth: %d)", self, rangeModeString, self.visibilityDepth);
#endif
  [self updateCurrentRangeModeWithModeIfPossible:rangeMode];
}

#pragma mark - Automatic range mode

- (BOOL)automaticallyAdjustRangeModeBasedOnViewEvents
{
  return _automaticallyAdjustRangeModeBasedOnViewEvents;
}

- (void)setAutomaticallyAdjustRangeModeBasedOnViewEvents:(BOOL)automaticallyAdjustRangeModeBasedOnViewEvents
{
  if (automaticallyAdjustRangeModeBasedOnViewEvents != _automaticallyAdjustRangeModeBasedOnViewEvents) {
    if (automaticallyAdjustRangeModeBasedOnViewEvents && _selfConformsToRangeModeProtocol == NO && _nodeConformsToRangeModeProtocol == NO) {
      NSLog(@"Warning: automaticallyAdjustRangeModeBasedOnViewEvents set to YES in %@, but range mode updating is not possible because neither view controller nor node %@ conform to ASRangeControllerUpdateRangeProtocol.", self, _node);
    }
    _automaticallyAdjustRangeModeBasedOnViewEvents = automaticallyAdjustRangeModeBasedOnViewEvents;
  }
}

- (void)updateCurrentRangeModeWithModeIfPossible:(ASLayoutRangeMode)rangeMode
{
  if (!_automaticallyAdjustRangeModeBasedOnViewEvents) {
    return;
  }
  
  if (_selfConformsToRangeModeProtocol) {
    id<ASRangeControllerUpdateRangeProtocol> rangeUpdater = (id<ASRangeControllerUpdateRangeProtocol>)self;
    [rangeUpdater updateCurrentRangeWithMode:rangeMode];
  }
  
  if (_nodeConformsToRangeModeProtocol) {
    id<ASRangeControllerUpdateRangeProtocol> rangeUpdater = (id<ASRangeControllerUpdateRangeProtocol>)_node;
    [rangeUpdater updateCurrentRangeWithMode:rangeMode];
  }
}

#pragma mark - Layout Helpers

- (ASSizeRange)nodeConstrainedSize
{
  return ASSizeRangeMake(self.view.bounds.size);
}

- (ASInterfaceState)interfaceState
{
  return _node.interfaceState;
}

#pragma mark - ASTraitEnvironment

- (ASPrimitiveTraitCollection)primitiveTraitCollectionForUITraitCollection:(UITraitCollection *)traitCollection
{
  if (self.overrideDisplayTraitsWithTraitCollection) {
    ASTraitCollection *asyncTraitCollection = self.overrideDisplayTraitsWithTraitCollection(traitCollection);
    return [asyncTraitCollection primitiveTraitCollection];
  }
  
  ASDisplayNodeAssertMainThread();
  ASPrimitiveTraitCollection asyncTraitCollection = ASPrimitiveTraitCollectionFromUITraitCollection(traitCollection);
  asyncTraitCollection.containerSize = self.view.frame.size;
  return asyncTraitCollection;
}

- (void)propagateNewTraitCollection:(ASPrimitiveTraitCollection)traitCollection
{
  ASPrimitiveTraitCollection oldTraitCollection = self.node.primitiveTraitCollection;
  
  if (ASPrimitiveTraitCollectionIsEqualToASPrimitiveTraitCollection(traitCollection, oldTraitCollection) == NO) {
    self.node.primitiveTraitCollection = traitCollection;
    
    NSArray<id<ASLayoutElement>> *children = [self.node sublayoutElements];
    for (id<ASLayoutElement> child in children) {
      ASTraitCollectionPropagateDown(child, traitCollection);
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Once we've propagated all the traits, layout this node.
    // Remeasure the node with the latest constrained size – old constrained size may be incorrect.
    [_node layoutThatFits:[self nodeConstrainedSize]];
#pragma clang diagnostic pop
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  
  ASPrimitiveTraitCollection traitCollection = [self primitiveTraitCollectionForUITraitCollection:self.traitCollection];
  traitCollection.containerSize = self.view.bounds.size;
  [self propagateNewTraitCollection:traitCollection];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
  
  ASPrimitiveTraitCollection traitCollection = _node.primitiveTraitCollection;
  traitCollection.containerSize = self.view.bounds.size;
  [self propagateNewTraitCollection:traitCollection];
}

@end
