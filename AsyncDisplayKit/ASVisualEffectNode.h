/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * This node adds a visual effect to any background for iOS8 and above.
 * Use this with an ASBackgroundLayoutSpec to layer it behind another node.
 *
 * Notes: If the node has trouble rendering you may have to send it's view
 * to the back on `didLoad`.
 *
 * Future plans: Child nodes should have their views added to the visualEffectView's
 * contentView and not it's subview.
 **/
NS_CLASS_AVAILABLE_IOS(8_0) @interface ASVisualEffectNode : ASDisplayNode

/**
 * Initialize with a visual effect.
 * @param visualEffect The UIVisualEffect which will be used to create the
 * UIVisualEffectView
 **/
- (instancetype)initWithEffect:(UIVisualEffect*)visualEffect;

/**
 * Return a ASVisualEffectNode with a blur effect.
 * @param effectStyle The style of blur to use to create the blur effect.
 **/
+ (instancetype)blurNodeWithEffect:(UIBlurEffectStyle)effectStyle;

/**
 * Returns the node's view as a UIVisualEffectView
 **/
@property (nonatomic, readonly) UIVisualEffectView *visualEffectView;

@end
