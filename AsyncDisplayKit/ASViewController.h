//
//  ASViewController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASVisibilityProtocols.h>

@class ASTraitCollection;

NS_ASSUME_NONNULL_BEGIN

typedef ASTraitCollection * _Nonnull (^ASDisplayTraitsForTraitCollectionBlock)(UITraitCollection *traitCollection);
typedef ASTraitCollection * _Nonnull (^ASDisplayTraitsForTraitWindowSizeBlock)(CGSize windowSize);

@interface ASViewController<__covariant DisplayNodeType : ASDisplayNode *> : UIViewController <ASVisibilityDepth>

- (instancetype)initWithNode:(DisplayNodeType)node NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) DisplayNodeType node;

/**
 * Set this block to customize the ASDisplayTraits returned when the VC transitions to the given traitCollection.
 */
@property (nonatomic, copy) ASDisplayTraitsForTraitCollectionBlock overrideDisplayTraitsWithTraitCollection;

/**
 * Set this block to customize the ASDisplayTraits returned when the VC transitions to the given window size.
 */
@property (nonatomic, copy) ASDisplayTraitsForTraitWindowSizeBlock overrideDisplayTraitsWithWindowSize;

/**
 * @abstract Passthrough property to the the .interfaceState of the node.
 * @return The current ASInterfaceState of the node, indicating whether it is visible and other situational properties.
 * @see ASInterfaceState
 */
@property (nonatomic, readonly) ASInterfaceState interfaceState;


// AsyncDisplayKit 2.0 BETA: This property is still being tested, but it allows
// blocking as a view controller becomes visible to ensure no placeholders flash onscreen.
// Refer to examples/SynchronousConcurrency, AsyncViewController.m
@property (nonatomic, assign) BOOL neverShowPlaceholders;


/**
 * The constrained size used to measure the backing node.
 *
 * @discussion Defaults to providing a size range that uses the view controller view's bounds as
 * both the min and max definitions. Override this method to provide a custom size range to the
 * backing node.
 */
- (ASSizeRange)nodeConstrainedSize;

@end

@interface ASViewController (ASRangeControllerUpdateRangeProtocol)

/// Automatically adjust range mode based on view events if the containing node confirms to the ASRangeControllerUpdateRangeProtocol
@property (nonatomic, assign) BOOL automaticallyAdjustRangeModeBasedOnViewEvents;

@end

NS_ASSUME_NONNULL_END