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
#import "ASDimension.h"
#import "ASDisplayNodeInternal.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Beta.h"
#import "ASTraitCollection.h"
#import "ASEnvironmentInternal.h"
#import "ASRangeControllerUpdateRangeProtocol+Beta.h"

#define AS_LOG_VISIBILITY_CHANGES 0

@implementation ASViewController
{
  BOOL _ensureDisplayed;
  BOOL _automaticallyAdjustRangeModeBasedOnViewEvents;
  BOOL _parentManagesVisibilityDepth;
  NSInteger _visibilityDepth;
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

  _automaticallyAdjustRangeModeBasedOnViewEvents = NO;

  return self;
}

- (void)dealloc
{
  if (_traitCollectionContext != nil) {
    // The setter will iterate through the VC's subnodes and replace the traitCollectionContext in their ASEnvironmentTraitCollection with nil.
    // Since the VC holds the only strong reference to this context and we are in the process of destroying
    // the VC, all the references in the subnodes will be unsafe unless we nil them out. More than likely all the subnodes will be dealloc'ed
    // as part of the VC being dealloc'ed, but this is just to make extra sure.
    self.traitCollectionContext = nil;
  }
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
  }
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  [_node measureWithSizeRange:[self nodeConstrainedSize]];
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
  [_node measureWithSizeRange:[self nodeConstrainedSize]];
  [_node recursivelyFetchData];
  
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
  _automaticallyAdjustRangeModeBasedOnViewEvents = automaticallyAdjustRangeModeBasedOnViewEvents;
}

- (void)updateCurrentRangeModeWithModeIfPossible:(ASLayoutRangeMode)rangeMode
{
  if (!_automaticallyAdjustRangeModeBasedOnViewEvents) { return; }
  if (![_node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)]) {
    return;
  }

  id<ASRangeControllerUpdateRangeProtocol> updateRangeNode = (id<ASRangeControllerUpdateRangeProtocol>)_node;
  [updateRangeNode updateCurrentRangeWithMode:rangeMode];
}

#pragma mark - Layout Helpers

- (ASSizeRange)nodeConstrainedSize
{
  CGSize viewSize = self.view.bounds.size;
  return ASSizeRangeMake(viewSize, viewSize);
}

- (ASInterfaceState)interfaceState
{
  return _node.interfaceState;
}

#pragma mark - ASEnvironmentTraitCollection

- (void)setTraitCollectionContext:(id)traitCollectionContext
{
  if (_traitCollectionContext != traitCollectionContext) {
    // nil out the displayContext in the subnodes so they aren't hanging around with a dealloc'ed pointer don't set
    // the new context yet as this will cause ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection to fail
    ASEnvironmentTraitCollectionUpdateDisplayContext(self.node, nil);
    
    _traitCollectionContext = traitCollectionContext;
  }
}

- (ASEnvironmentTraitCollection)environmentTraitCollectionForUITraitCollection:(UITraitCollection *)traitCollection
{
  if (self.overrideDisplayTraitsWithTraitCollection) {
    ASTraitCollection *asyncTraitCollection = self.overrideDisplayTraitsWithTraitCollection(traitCollection);
    self.traitCollectionContext = asyncTraitCollection.traitCollectionContext;
    return [asyncTraitCollection environmentTraitCollection];
  }
  
  ASEnvironmentTraitCollection asyncTraitCollection = ASEnvironmentTraitCollectionFromUITraitCollection(traitCollection);
  asyncTraitCollection.displayContext = self.traitCollectionContext;
  return asyncTraitCollection;
}

- (ASEnvironmentTraitCollection)environmentTraitCollectionForWindowSize:(CGSize)windowSize
{
  if (self.overrideDisplayTraitsWithWindowSize) {
    ASTraitCollection *traitCollection = self.overrideDisplayTraitsWithWindowSize(windowSize);
    self.traitCollectionContext = traitCollection.traitCollectionContext;
    return [traitCollection environmentTraitCollection];
  }
  return self.node.environmentTraitCollection;
}

- (void)progagateNewEnvironmentTraitCollection:(ASEnvironmentTraitCollection)environmentTraitCollection
{
  ASEnvironmentState environmentState = self.node.environmentState;
  ASEnvironmentTraitCollection oldEnvironmentTraitCollection = environmentState.environmentTraitCollection;
  
  if (ASEnvironmentTraitCollectionIsEqualToASEnvironmentTraitCollection(environmentTraitCollection, oldEnvironmentTraitCollection) == NO) {
    environmentState.environmentTraitCollection = environmentTraitCollection;
    self.node.environmentState = environmentState;
    [self.node setNeedsLayout];
    
    NSArray<id<ASEnvironment>> *children = [self.node children];
    for (id<ASEnvironment> child in children) {
      ASEnvironmentStatePropagateDown(child, environmentState.environmentTraitCollection);
    }
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  
  ASEnvironmentTraitCollection environmentTraitCollection = [self environmentTraitCollectionForUITraitCollection:self.traitCollection];
  [self progagateNewEnvironmentTraitCollection:environmentTraitCollection];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
  
  ASEnvironmentTraitCollection environmentTraitCollection = [self environmentTraitCollectionForUITraitCollection:newCollection];
  [self progagateNewEnvironmentTraitCollection:environmentTraitCollection];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  
  ASEnvironmentTraitCollection environmentTraitCollection = [self environmentTraitCollectionForWindowSize:size];
  [self progagateNewEnvironmentTraitCollection:environmentTraitCollection];
}

@end
