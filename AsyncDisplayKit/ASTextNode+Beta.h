//
//  ASTextNode+Beta.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//


@interface ASDisplayNode (Beta)

/**
 @abstract The minimum scale that the textnode can apply to fit long words.
 @default 0 (No scaling)
 */
@property (nonatomic, assign) CGFloat minimumScaleFactor;

@end