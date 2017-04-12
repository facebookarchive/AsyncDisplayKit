//
//  ASDisplayNodeTipState.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASDisplayNode, ASTipNode;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASDisplayNodeTipState : NSObject

- (instancetype)initWithNode:(ASDisplayNode *)node NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// Unsafe because once the node is deallocated, we will not be able to access the tip state.
@property (nonatomic, unsafe_unretained, readonly) ASDisplayNode *node;

/// Main-thread-only.
@property (nonatomic, strong, nullable) ASTipNode *tipNode;

@end

NS_ASSUME_NONNULL_END
