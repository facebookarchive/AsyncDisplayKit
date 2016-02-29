//
//  ASViewController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASViewController<__covariant DisplayNodeType : ASDisplayNode *> : UIViewController

- (instancetype)initWithNode:(DisplayNodeType)node NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) DisplayNodeType node;

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

NS_ASSUME_NONNULL_END