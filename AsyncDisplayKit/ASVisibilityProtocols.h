//
//  ASVisibilityProtocols.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/27/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "ASLayoutRangeType.h"

#import "ASBaseDefines.h"

@class UIViewController;

ASDISPLAYNODE_EXTERN_C_BEGIN

extern ASLayoutRangeMode ASLayoutRangeModeForVisibilityDepth(NSUInteger visibilityDepth);

ASDISPLAYNODE_EXTERN_C_END

@protocol ASVisibilityDepth <NSObject>

/**
 * @abstract Represents the number of user actions necessary to reach the view controller. An increased visibility
 * depth indicates a higher number of user interactions for the view controller to be visible again. For example,
 * an onscreen navigation controller's top view controller should have a visibility depth of 0. The view controller
 * one from the top should have a visibility deptch of 1 as should the root view controller in the stack (because
 * the user can hold the back button to pop to the root view controller).
 *
 * Visibility depth is used to automatically adjust ranges on range controllers (and thus free up memory) and can
 * be used to reduce memory usage of other items as well.
 */
- (NSInteger)visibilityDepth;


- (void)visibilityDepthDidChange;

@end

/**
 * @abstract Container view controllers should adopt this protocol to indicate that they will manage their child's
 * visibilityDepth. For example, ASNavigationController adopts this protocol and manages its childrens visibility
 * depth.
 *
 * If you adopt this protocol, you *must* also emit visibilityDepthDidChange messages to child view controllers.
 *
 * @param childViewController Expected to return the visibility depth of the child view controller.
 */
@protocol ASManagesChildVisibilityDepth <ASVisibilityDepth>

- (NSInteger)visibilityDepthOfChildViewController:(UIViewController *)childViewController;

@end

#define ASVisibilitySetVisibilityDepth \
- (void)setVisibilityDepth:(NSUInteger)visibilityDepth \
{ \
  if (_visibilityDepth == visibilityDepth) { \
    return; \
  } \
  _visibilityDepth = visibilityDepth; \
  [self visibilityDepthDidChange]; \
}

#define ASVisibilityDepthImplementation \
- (NSInteger)visibilityDepth \
{ \
  if (self.parentViewController && _parentManagesVisibilityDepth == NO) { \
    _parentManagesVisibilityDepth = [self.parentViewController conformsToProtocol:@protocol(ASManagesChildVisibilityDepth)]; \
  } \
  \
  if (_parentManagesVisibilityDepth) { \
    return [(id <ASManagesChildVisibilityDepth>)self.parentViewController visibilityDepthOfChildViewController:self]; \
  } \
  return _visibilityDepth; \
}

#define ASVisibilityViewDidDisappearImplementation \
- (void)viewDidDisappear:(BOOL)animated \
{ \
  [super viewDidDisappear:animated]; \
  \
  if (_parentManagesVisibilityDepth == NO) { \
    [self setVisibilityDepth:1]; \
  } \
}

#define ASVisibilityViewWillAppear \
- (void)viewWillAppear:(BOOL)animated \
{ \
  [super viewWillAppear:animated]; \
  \
  if (_parentManagesVisibilityDepth == NO) { \
    [self setVisibilityDepth:0]; \
  } \
}

#define ASVisibilityDidMoveToParentViewController \
- (void)didMoveToParentViewController:(UIViewController *)parent \
{ \
  [super didMoveToParentViewController:parent]; \
  _parentManagesVisibilityDepth = NO; \
  [self visibilityDepthDidChange]; \
}
