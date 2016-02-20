//
//  ASCellNode+Internal.h
//  Pods
//
//  Created by Max Gu on 2/19/16.
//
//

#import "ASCellNode.h"

@protocol ASCellNodeLayoutDelegate <NSObject>

/**
 * Notifies the delegate that the specified cell node has done a relayout.
 * The notification is done on main thread.
 *
 * This will not be called due to measurement passes before the node has loaded
 * its view, even if triggered by -setNeedsLayout, as it is assumed these are
 * not relevant to UIKit.  Indeed, these calls can cause consistency issues.
 *
 * @param node A node informing the delegate about the relayout.
 * @param sizeChanged `YES` if the node's `calculatedSize` changed during the relayout, `NO` otherwise.
 */
- (void)nodeDidRelayout:(ASCellNode *)node sizeChanged:(BOOL)sizeChanged;

@end

@interface ASCellNode ()

/*
 * A delegate to be notified (on main thread) after a relayout.
 */
@property (nonatomic, weak) id<ASCellNodeLayoutDelegate> layoutDelegate;

@end
