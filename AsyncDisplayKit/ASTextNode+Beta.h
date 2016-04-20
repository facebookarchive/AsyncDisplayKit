//
//  ASTextNode+Beta.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@interface ASTextNode ()

/**
 @abstract An array of descending scale factors that will be applied to this text node to try to make it fit within its constrained size
 @default nil (no scaling)
 */
@property (nullable, nonatomic, copy) NSArray *pointSizeScaleFactors;

#pragma mark - ASTextKit Customization
/**
 A block to provide a hook to provide a custom NSLayoutManager to the ASTextKitRenderer
 */
@property (nullable, nonatomic, copy) NSLayoutManager * (^layoutManagerCreationBlock)(void);

/**
 A block to provide a hook to provide a NSTextStorage to the TextKit's layout manager.
 */
@property (nullable, nonatomic, copy) NSTextStorage * (^textStorageCreationBlock)(NSAttributedString *_Nullable attributedString);

@end

NS_ASSUME_NONNULL_END
