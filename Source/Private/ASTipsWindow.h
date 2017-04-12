//
//  ASTipsWindow.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASViewController.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode, ASDisplayNodeTipState;

NS_ASSUME_NONNULL_BEGIN

/**
 * A window that shows tips. This was originally meant to be a view controller
 * but UIKit will not manage view controllers in non-key windows correctly AT ALL
 * as of the time of this writing.
 */
AS_SUBCLASSING_RESTRICTED
@interface ASTipsWindow : UIWindow

/// The main application window that the tips are tracking.
@property (nonatomic, weak) UIWindow *mainWindow;

@property (nonatomic, copy, nullable) NSMapTable<ASDisplayNode *, ASDisplayNodeTipState *> *nodeToTipStates;

@end

NS_ASSUME_NONNULL_END

#endif
