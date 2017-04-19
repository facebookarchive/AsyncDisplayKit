//
//  ASComponentHostingNode.mm
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#if __has_include(<ComponentKit/ComponentKit.h>)

#import "ASComponentHostingNode.h"

#import <ComponentKit/CKComponentLayout.h>
#import <ComponentKit/CKComponentProvider.h>
#import <ComponentKit/CKComponentRootView.h>
#import <ComponentKit/CKComponentScopeRoot.h>
#import <ComponentKit/CKComponentSizeRangeProviding.h>

#import "ASAssert.h"
#import "ASDisplayNode+Subclasses.h"

NS_ASSUME_NONNULL_BEGIN

struct ASComponentHostingViewInputs {
  CKComponentScopeRoot *scopeRoot;
  id<NSObject> _Nullable model;
  id<NSObject> _Nullable context;
  CKComponentStateUpdateMap stateUpdates;
};

@interface ASComponentHostingNode () <CKComponentStateListener>
{
  Class<CKComponentProvider> _componentProvider;
  id<CKComponentSizeRangeProviding> _sizeRangeProvider;

  CKComponent *_component;
  ASDisplayNode *_containerNode;

  CKComponentLayout _mountedLayout;
  NSSet *_mountedComponents;

  CKUpdateMode _requestedUpdateMode;
  ASComponentHostingViewInputs _pendingInputs;
  BOOL _componentNeedsUpdate;
  BOOL _scheduledAsynchronousComponentUpdate;
  BOOL _isSynchronouslyUpdatingComponent;
}

@end

@implementation ASComponentHostingNode

#pragma Mark - Lifecycle

- (instancetype)initWithComponentProvider:(Class<CKComponentProvider>)componentProvider
                        sizeRangeProvider:(id<CKComponentSizeRangeProviding>)sizeRangeProvider
{
  self = [super init];

  _containerNode = [[ASDisplayNode alloc] initWithViewBlock:^{
    return [CKComponentRootView new];
  }];
  [self addSubnode:_containerNode];

  _componentProvider = componentProvider;
  _sizeRangeProvider = sizeRangeProvider;

  _pendingInputs = { .scopeRoot = [CKComponentScopeRoot rootWithListener:self] };
  _componentNeedsUpdate = YES;
  _requestedUpdateMode = CKUpdateModeAsynchronous;

  [self _asynchronouslyUpdateComponentIfNeeded];

  return self;
}

- (void)dealloc
{
  CKUnmountComponents(_mountedComponents);
}

#pragma mark - ASDisplayNode+Subclasses

- (void)layout
{
  [super layout];

  _containerNode.frame = self.bounds;
  const CGSize size = self.calculatedSize;
  if (_mountedLayout.component != _component || !CGSizeEqualToSize(_mountedLayout.size, size)) {
    _mountedLayout = CKComputeComponentLayout(_component, {size, size}, size);
  }
  _mountedComponents = CKMountComponentLayout(_mountedLayout, _containerNode.view, _mountedComponents, nil);
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  const CKSizeRange componentConstrainedSize = [_sizeRangeProvider sizeRangeForBoundingSize:constrainedSize];
  return CKComputeComponentLayout(_component, componentConstrainedSize, componentConstrainedSize.max).size;
}

#pragma mark - CKComponentStateListener

- (void)componentScopeHandleWithIdentifier:(CKComponentScopeHandleIdentifier)globalIdentifier
                            rootIdentifier:(CKComponentScopeRootIdentifier)rootIdentifier
                     didReceiveStateUpdate:(nullable id (^)(_Nullable id))stateUpdate
                                      mode:(CKUpdateMode)mode
{
  _pendingInputs.stateUpdates.insert({globalIdentifier, stateUpdate});
  [self _setNeedsUpdateWithMode:mode];
}

#pragma mark - Accessors

- (void)updateModel:(nullable id<NSObject>)model mode:(CKUpdateMode)mode
{
  _pendingInputs.model = model;
  [self _setNeedsUpdateWithMode:mode];
}

- (void)updateContext:(nullable id<NSObject>)context mode:(CKUpdateMode)mode
{
  _pendingInputs.context = context;
  [self _setNeedsUpdateWithMode:mode];
}

#pragma mark - Private

- (void)_setNeedsUpdateWithMode:(CKUpdateMode)mode
{
  if (_componentNeedsUpdate && _requestedUpdateMode == CKUpdateModeSynchronous) {
    return; // Already scheduled a synchronous update; nothing more to do.
  }

  _componentNeedsUpdate = YES;
  _requestedUpdateMode = mode;

  switch (mode) {
    case CKUpdateModeAsynchronous:
      [self _asynchronouslyUpdateComponentIfNeeded];
      break;
    case CKUpdateModeSynchronous:
      [self _synchronouslyUpdateComponentIfNeeded];
      [self _invalidateLayout];
      break;
  }
}

- (void)_asynchronouslyUpdateComponentIfNeeded
{
  if (_scheduledAsynchronousComponentUpdate) {
    return;
  }
  _scheduledAsynchronousComponentUpdate = YES;

  // Wait until the end of the run loop so that if multiple async updates are triggered we don't thrash.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    if (_requestedUpdateMode != CKUpdateModeAsynchronous) {
      // A synchronous update was either scheduled or completed, so we can skip the async update.
      _scheduledAsynchronousComponentUpdate = NO;
      return;
    }

    if (!_componentNeedsUpdate) {
      // A synchronous update snuck in and took care of it for us.
      return;
    }

    _scheduledAsynchronousComponentUpdate = NO;
    [self _updateComponent];
    [self _invalidateLayout];
  });
}

- (void)_synchronouslyUpdateComponentIfNeeded
{
  if (_componentNeedsUpdate == NO || _requestedUpdateMode == CKUpdateModeAsynchronous) {
    return;
  }

  ASDisplayNodeAssert
  (!_isSynchronouslyUpdatingComponent,
   @"ASComponentHostingNode is not re-entrant. This is called by -layoutSubviews, so ensure "
   @"that there is nothing that is triggering a nested call to -layoutSubviews.");

  _isSynchronouslyUpdatingComponent = YES;
  [self _updateComponent];
  _isSynchronouslyUpdatingComponent = NO;
}

- (void)_updateComponent
{
  auto result = CKBuildComponent(_pendingInputs.scopeRoot, _pendingInputs.stateUpdates, ^{
    return [_componentProvider componentForModel:_pendingInputs.model
                                         context:_pendingInputs.context];
  });

  _pendingInputs.scopeRoot = result.scopeRoot;
  _pendingInputs.stateUpdates = {};
  _component = result.component;
  _componentNeedsUpdate = NO;
}

- (void)_invalidateLayout
{
  [self invalidateCalculatedLayout];
  [_delegate componentHostingNodeDidInvalidateSize:self];
}

@end

NS_ASSUME_NONNULL_END

#endif
