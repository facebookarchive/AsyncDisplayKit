//
//  ASDisplayNodeDebugUI.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASDisplayNodeDebugUIManager : NSObject

/**
 * The shared debug UI manager instance.
 */
+ (ASDisplayNodeDebugUIManager *)sharedManager;

/**
 * Show the debug UI with the given node.
 *
 * @param node The node to be tested. This node should not be in a hierarchy.
 * @param sizes The sizes of the node when the UI is initially shown.
 *   You can pass nil to use the size of the screen.
 *
 * @discussion The debug UI will be shown in a new window that fills the screen.
 */
- (void)showDebugUIWithNode:(ASDisplayNode *)node sizes:(nullable NSArray<NSValue *> *)sizes;

/**
 * Dismiss the debug UI if it's currently shown.
 */
- (void)dismissDebugUI;

@end

NS_ASSUME_NONNULL_END
