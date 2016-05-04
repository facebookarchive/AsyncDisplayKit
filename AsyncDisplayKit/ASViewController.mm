//
//  ASViewController.m
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASViewController.h"
#import "ASAssert.h"
#import "ASDimension.h"
#import "ASDisplayNode+FrameworkPrivate.h"
#import "ASDisplayNode+Beta.h"
#import "ASEnvironmentInternal.h"
#import "ASRangeControllerUpdateRangeProtocol+Beta.h"

@implementation ASViewController
{
  BOOL _ensureDisplayed;
  BOOL _automaticallyAdjustRangeModeBasedOnViewEvents;
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
  if (_displayTraitsContext != nil) {
    ASDisplayTraitsClearDisplayContext(self.node);
    _displayTraitsContext = nil;
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

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  _ensureDisplayed = YES;
  [_node measureWithSizeRange:[self nodeConstrainedSize]];
  [_node recursivelyFetchData];
    
  [self updateCurrentRangeModeWithModeIfPossible:ASLayoutRangeModeFull];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  
  [self updateCurrentRangeModeWithModeIfPossible:ASLayoutRangeModeMinimum];
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
  if (![_node conformsToProtocol:@protocol(ASRangeControllerUpdateRangeProtocol)]) { return; }

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

#pragma mark - ASDisplayTraits

- (ASEnvironmentDisplayTraits)displayTraitsForTraitCollection:(UITraitCollection *)traitCollection
{
  if (self.overrideDisplayTraitsWithTraitCollection) {
    return self.overrideDisplayTraitsWithTraitCollection(traitCollection);
  }
  
  ASEnvironmentDisplayTraits displayTraits = ASEnvironmentDisplayTraitsFromUITraitCollection(traitCollection);
  displayTraits.displayContext = _displayTraitsContext;
  return displayTraits;
}

- (ASEnvironmentDisplayTraits)displayTraitsForWindowSize:(CGSize)windowSize
{
  if (self.overrideDisplayTraitsWithWindowSize) {
    return self.overrideDisplayTraitsWithWindowSize(windowSize);
  }
  return self.node.environmentState.displayTraits;
}

- (void)progagateNewDisplayTraits:(ASEnvironmentDisplayTraits)displayTraits
{
  ASEnvironmentState environmentState = self.node.environmentState;
  ASEnvironmentDisplayTraits oldDisplayTraits = environmentState.displayTraits;
  
  if (ASEnvironmentDisplayTraitsIsEqualToASEnvironmentDisplayTraits(displayTraits, oldDisplayTraits) == NO) {
    environmentState.displayTraits = displayTraits;
    [self.node setEnvironmentState:environmentState];
    [self.node setNeedsLayout];
    
    NSArray<id<ASEnvironment>> *children = [self.node children];
    for (id<ASEnvironment> child in children) {
      ASEnvironmentStatePropagateDown(child, environmentState.displayTraits);
    }
  }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
  [super traitCollectionDidChange:previousTraitCollection];
  
  ASEnvironmentDisplayTraits displayTraits = [self displayTraitsForTraitCollection:self.traitCollection];
  [self progagateNewDisplayTraits:displayTraits];
}

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
  
  ASEnvironmentDisplayTraits displayTraits = [self displayTraitsForTraitCollection:self.traitCollection];
  [self progagateNewDisplayTraits:displayTraits];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
  [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
  
  ASEnvironmentDisplayTraits displayTraits = [self displayTraitsForWindowSize:size];
  [self progagateNewDisplayTraits:displayTraits];
}

@end
