//
//  ASTextNode+Beta.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//


@interface ASTextNode ()

/**
 @abstract An array of descending scale factors that will be applied to this text node to try to make it fit within its constrained size
 @default nil (no scaling)
 */
@property (nonatomic, copy) NSArray *pointSizeScaleFactors;

#pragma mark - ASTextKit Customization
/**
 A block to provide a hook to provide a custom NSLayoutManager to the ASTextKitRenderer
 */
@property (nonatomic, copy) NSLayoutManager * (^layoutManagerCreationBlock)(void);

/**
 A block to provide a hook to provide a NSTextStorage to the Text Kit's layout manager.
 */
@property (nonatomic, copy) NSTextStorage * (^textStorageCreationBlock)(NSAttributedString *attributedString);


@end