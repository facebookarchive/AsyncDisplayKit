//
//  ASTipsController.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASDisplayNode;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASTipsController : NSObject

/**
 * The shared tip controller instance.
 */
@property (class, strong, readonly) ASTipsController *shared;

#pragma mark - Node Event Hooks

/**
 * Informs the controller that the sender did enter the visible range.
 *
 * The controller will run a pass with its tip providers, adding tips as needed.
 */
- (void)nodeDidAppear:(ASDisplayNode *)node;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
