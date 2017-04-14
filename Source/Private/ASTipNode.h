//
//  ASTipNode.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASControlNode.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

@class ASTip;

NS_ASSUME_NONNULL_BEGIN

/**
 * ASTipNode will send these up the responder chain.
 */
@protocol ASTipNodeActions <NSObject>
- (void)didTapTipNode:(id)sender;
@end

AS_SUBCLASSING_RESTRICTED
@interface ASTipNode : ASControlNode

- (instancetype)initWithTip:(ASTip *)tip NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@property (nonatomic, strong, readonly) ASTip *tip;

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
