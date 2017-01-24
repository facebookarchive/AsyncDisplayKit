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

#import <AsyncDisplayKit/ASBaseDefines.h>
#import <AsyncDisplayKit/ASLayoutRangeType.h>

NS_ASSUME_NONNULL_BEGIN

@class UIViewController;

ASDISPLAYNODE_EXTERN_C_BEGIN

extern ASLayoutRangeMode ASLayoutRangeModeForVisibilityDepth(NSUInteger visibilityDepth);

ASDISPLAYNODE_EXTERN_C_END

/**
 * ASVisibilityDepth
 *
 * @discussion "Visibility Depth" represents the number of user actions required to make an ASDisplayNode or 
 * ASViewController visibile. AsyncDisplayKit uses this information to intelligently manage memory and focus
 * resources where they are most visible to the user.
 *
 * The ASVisibilityDepth protocol describes how custom view controllers can integrate with this system.
 *
 * Parent view controllers should also implement @c ASManagesChildVisibilityDepth
 *
 * @see ASManagesChildVisibilityDepth
 */

@protocol ASVisibilityDepth <NSObject>

/**
 * Visibility depth
 *
 * @discussion Represents the number of user actions necessary to reach the view controller. An increased visibility
 * depth indicates a higher number of user interactions for the view controller to be visible again. For example,
 * an onscreen navigation controller's top view controller should have a visibility depth of 0. The view controller
 * one from the top should have a visibility deptch of 1 as should the root view controller in the stack (because
 * the user can hold the back button to pop to the root view controller).
 *
 * Visibility depth is used to automatically adjust ranges on range controllers (and thus free up memory) and can
 * be used to reduce memory usage of other items as well.
 */
- (NSInteger)visibilityDepth;

/**
 * Called when visibility depth changes
 *
 * @discussion @c visibilityDepthDidChange is called whenever the visibility depth of the represented view controller
 * has changed.
 * 
 * If implemented by a view controller container, use this method to notify child view controllers that their view
 * depth has changed @see ASNavigationController.m
 *
 * If implemented on an ASViewController, use this method to reduce or increase the resources that your
 * view controller uses. A higher visibility depth view controller should decrease it's resource usage, a lower
 * visibility depth controller should pre-warm resources in preperation for a display at 0 depth.
 *
 * ASViewController implements this method and reduces / increases range mode of supporting nodes (such as ASCollectionNode
 * and ASTableNode).
 *
 * @see visibilityDepth
 */
- (void)visibilityDepthDidChange;

@end

/**
 * ASManagesChildVisibilityDepth
 *
 * @discussion A protocol which should be implemented by container view controllers to allow proper
 * propagation of visibility depth
 *
 * @see ASVisibilityDepth
 */
@protocol ASManagesChildVisibilityDepth <ASVisibilityDepth>

/**
 * @abstract Container view controllers should adopt this protocol to indicate that they will manage their child's
 * visibilityDepth. For example, ASNavigationController adopts this protocol and manages its childrens visibility
 * depth.
 *
 * If you adopt this protocol, you *must* also emit visibilityDepthDidChange messages to child view controllers.
 *
 * @param childViewController Expected to return the visibility depth of the child view controller.
 */
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

NS_ASSUME_NONNULL_END
