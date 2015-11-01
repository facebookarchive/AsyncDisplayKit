/* Copyright (c) 2014-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <AsyncDisplayKit/ASDisplayNode.h>

@class ASCellNode;

typedef NSUInteger ASCellNodeAnimation;

@protocol ASCellNodeLayoutDelegate <NSObject>

/**
 * Notifies the delegate that the specified cell node has done a relayout.
 * The notification is done on main thread.
 *
 * @param node A node informing the delegate about the relayout.
 *
 * @param suggestedAnimation A constant indicates how the delegate should animate. See UITableViewRowAnimation.
 */
- (void)node:(ASCellNode *)node didRelayoutWithSuggestedAnimation:(ASCellNodeAnimation)animation;
@end

/**
 * Generic cell node.  Subclass this instead of `ASDisplayNode` to use with `ASTableView` and `ASCollectionView`.
 */
@interface ASCellNode : ASDisplayNode

/**
 * @abstract When enabled, ensures that the cell is completely displayed before allowed onscreen.
 *
 * @default NO
 * @discussion Normally, ASCellNodes are preloaded and have finished display before they are onscreen.
 * However, if the Table or Collection's rangeTuningParameters are set to small values (or 0),
 * or if the user is scrolling rapidly on a slow device, it is possible for a cell's display to
 * be incomplete when it becomes visible.
 *
 * In this case, normally placeholder states are shown and scrolling continues uninterrupted.
 * The finished, drawn content is then shown as soon as it is ready.
 *
 * With this property set to YES, the main thread will be blocked until display is complete for
 * the cell.  This is more similar to UIKit, and in fact makes AsyncDisplayKit scrolling visually
 * indistinguishible from UIKit's, except being faster.
 *
 * Using this option does not eliminate all of the performance advantages of AsyncDisplayKit.
 * Normally, a cell has been preloading and is almost done when it reaches the screen, so the
 * blocking time is very short.  If the rangeTuningParameters are set to 0, still this option
 * outperforms UIKit: while the main thread is waiting, subnode display executes concurrently.
 */
@property (nonatomic, assign) BOOL neverShowPlaceholders;

/*
 * ASTableView uses these properties when configuring UITableViewCells that host ASCellNodes.
 */
//@property (atomic, retain) UIColor *backgroundColor;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;

/*
 * A Boolean value that indicates whether the node is selected.
 */
@property (nonatomic, assign) BOOL selected;

/*
 * A Boolean value that indicates whether the node is highlighted.
 */
@property (nonatomic, assign) BOOL highlighted;

/*
 * A delegate to be notified (on main thread) after a relayout.
 */
@property (nonatomic, weak) id<ASCellNodeLayoutDelegate> layoutDelegate;

/*
 * A constant that is passed to the delegate to indicate how a relayout is to be animated.
 * 
 * @see UITableViewRowAnimation
 */
@property (nonatomic, assign) ASCellNodeAnimation relayoutAnimation;

/*
 * ASCellNode must forward touch events in order for UITableView and UICollectionView tap handling to work. Overriding
 * these methods (e.g. for highlighting) requires the super method be called.
 */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event ASDISPLAYNODE_REQUIRES_SUPER;

/**
 * Marks the node as needing layout. Convenience for use whether the view / layer is loaded or not. Safe to call from a background thread.
 *
 * If this node was measured, calling this method triggers an internal relayout: the calculated layout is invalidated,
 * and the supernode is notified or (if this node is the root one) a full measurement pass is executed using the old constrained size.
 * The delegate will then be notified on main thread.
 *
 * This method can be called inside of an animation block (to animate all of the layout changes).
 */
- (void)setNeedsLayout;

@end


/**
 * Simple label-style cell node.  Read its source for an example of custom <ASCellNode>s.
 */
@interface ASTextCellNode : ASCellNode

/**
 * Text to display.
 */
@property (nonatomic, copy) NSString *text;

@end
