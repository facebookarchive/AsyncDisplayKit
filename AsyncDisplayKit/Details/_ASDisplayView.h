/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <UIKit/UIKit.h>


// This class is only for use by ASDisplayNode and should never be subclassed or used directly.
// Note that the "node" property is added to UIView directly via a category in ASDisplayNode.

@interface _ASDisplayView : UIView

// These methods expose a way for ASDisplayNode touch events to let the view call super touch events
// Some UIKit mechanisms, like UITableView and UICollectionView selection handling, require this to work
- (void)__forwardTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)__forwardTouchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@end
