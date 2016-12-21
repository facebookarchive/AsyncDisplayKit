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

#import "ASViewController.h"
#import "ASAssert.h"
#import "ASAvailability.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASLayout.h"
#import "ASTraitCollection.h"
#import "ASEnvironmentInternal.h"
#import "ASRangeControllerUpdateRangeProtocol+Beta.h"
#import "ASInternalHelpers.h"

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
  ASDisplayNodeAssert(NO, @"ASViewController requires using -initWithNode:");
  return [self initWithNode:[[ASDisplayNode alloc] init]];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
  ASDisplayNodeAssert(NO, @"ASViewController requires using -initWithNode:");
  return [self initWithNode:[[ASDisplayNode alloc] init]];
}

- (instancetype)initWithNode:(ASDisplayNode *)node
{
  if (!(self = [super initWithNibName:nil bundle:nil])) {
    return nil;
  }
  
  ASDisplayNodeAssertNotNil(node, @"Node must not be nil");
  ASDisplayNodeAssertTrue(!node.layerBacked);
  _node = node;

  _selfConformsToRangeModeProtocol = [self conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _nodeConformsToRangeModeProtocol = [_node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)];
  _automaticallyAdjustRangeModeBasedOnViewEvents = _selfConformsToRangeModeProtocol || _nodeConformsToRangeModeProtocol;
  
  // In case the node will get loaded
  if (_node.nodeLoaded) {
    // Node already loaded the view
    [self view];
  } else {
    // If the node didn't load yet add ourselves as on did load observer to laod the view in case the node gets loaded
    // before the view controller
    __weak __typeof__(self) weakSelf = self;
    [_node onDidLoad:^(__kindof ASDisplayNode * _Nonnull node) {
      if ([weakSelf isViewLoaded] == NO) {
        [weakSelf view];
      }
    }];
  }

  return self;
}

- (void)dealloc
{
  ASPerformBackgroundDeallocation(_node);
}

- (void)loadView
{
  ASDisplayNodeAssertTrue(!_node.layerBacked);
  
  // Apple applies a frame and autoresizing masks we need.  Allocating a view is not
  // nearly as expensive as adding and removing it from a hierarchy, and fortunately
  // we can avoid that here.  Enabling layerBacking on a single node in the hierarchy
  // will have a greater performance benefit than the impact of this transient view.
  [super loadView];
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
  if (AS_AT_LEAST_IOS8) {
    ASEnvironmentTraitCollection traitCollection = [self environmentTraitCollectionForUITraitCollection:self.traitCollection];
    [self progagateNewEnvironmentTraitCollection:traitCollection];
  } else {
    ASEnvironmentTraitCollection traitCollection = ASEnvironmentTraitCollectionMakeDefault();
    traitCollection.containerSize = self.view.bounds.size;
    [self progagateNewEnvironmentTraitCollection:traitCollection];
  }
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  
  // Before layout, make sure that our trait collection containerSize actually matches the size of our bounds.
  // If not, we need to update the traits and propagate them.
  if (CGSizeEqualToSize(self.node.environmentTraitCollection.containerSize, self.view.bounds.size) == NO) {
    [UIView performWithoutAnimation:^{
      ASEnvironmentTraitCollection environmentTraitCollection;
      if (AS_AT_LEAST_IOS8) {
        environmentTraitCollection = [self environmentTraitCollectionForUITraitCollection:self.traitCollection];
      } else {
        environmentTraitCollection = ASEnvironmentTraitCollectionMakeDefault();
      }
      environmentTraitCollection.containerSize = self.view.bounds.size;
      // this method will call measure
      [self progagateNewEnvironmentTraitCollection:environmentTraitCollection];
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
    [self.node recursivelyEnsureDisplaySynchronously:YES];
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
  if (!_automaticallyAdjustRangeModeBasedOnViewEvents) { return; }
  
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

#pragma mark - ASEnvironmentTraitCollection

- (ASEnvironmentTraitCollection)environmentTraitCollectionForUITraitCollection:(UITraitCollection *)traitCollection
{
  if (self.overrideDisplayTraitsWithTraitCollection) {
    ASTraitCollection *asyncTraitCollection = self.overrideDisplayTraitsWithTraitCollection(traitCollection);
    return [asyncTraitCollection environmentTraitCollection];
  }
  
  ASDisplayNodeAssertMainThread();
  ASEnvironmentTraitCollection asyncTraitCollection = ASEnvironmentTraitCollectionFromUITraitCollection(traitCollection);
  asyncTraitCollection.containerSize = self.view.frame.size;
  return asyncTraitCollection;
}

- (void)progagateNewEnvironmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  ASEnvironmentState environmentState = self.node.environmentState;
  ASEnvironmentTraitCollection oldEnvironmentTraitCollection = environmentState.environmentTraitCollection;
  
  if (ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(environmentTraitCollection, oldEnvironmentTraitCollection) == NO) {
    environmentState.environmentTraitCollection = environmentTraitCollection;
    self.node.environmentState = environmentState;
    
    NSArray<id<ASEnvironment>> *children = [self.node children];
    for (id<ASEnvironment> child in children) {
      ASEnvironmentStatePropagateDown(child, environmentState.environmentTraitCollection);
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // Once we've propagated all the traits, layout this node.
    // Remeasure the node with the latest constrained size – old constrained size may be incorrect.
    [self.node layoutThatFits:[self nodeConstrainedSize]];
#pragma clang diagnostic pop
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  
  ASEnvironmentTraitCollection environmentTraitCollection = [self environmentTraitCollectionForUITraitCollection:self.traitCollection];
  environmentTraitCollection.containerSize = self.view.bounds.size;
  [self progagateNewEnvironmentTraitCollection:environmentTraitCollection];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
  
  ASEnvironmentTraitCollection traitCollection = self.node.environmentTraitCollection;
  traitCollection.containerSize = self.view.bounds.size;
  [self progagateNewEnvironmentTraitCollection:traitCollection];
}

@end
