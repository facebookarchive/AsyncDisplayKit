//
//  ASViewController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

@interface ASViewController : UIViewController

@property (nonatomic, strong, readonly) ASDisplayNode *node;

// AsyncDisplayKit 2.0 BETA: This property is still being tested, but it allows
// blocking as a view controller becomes visible to ensure no placeholders flash onscreen.
// Refer to examples/SynchronousConcurrency, AsyncViewController.m
@property (nonatomic, assign) BOOL neverShowPlaceholders;

- (instancetype)initWithNode:(ASDisplayNode *)node;

/**
 * The constrained size used to measure the backing node.
 *
 * @discussion Defaults to providing a size range that uses the view controller view's bounds as
 * both the min and max definitions. Override this method to provide a custom size range to the
 * backing node.
 */
- (ASSizeRange)nodeConstrainedSize;

@end
