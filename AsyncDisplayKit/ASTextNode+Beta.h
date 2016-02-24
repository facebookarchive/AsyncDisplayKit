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

/**
 @abstract The currently applied scale factor, or 0 if the text node is not being scaled.
 */
@property (nonatomic, assign, readonly) CGFloat currentScaleFactor;

@end