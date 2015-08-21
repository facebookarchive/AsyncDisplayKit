//
//  ASBaselineStackLayoutable.h
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 8/21/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASStackLayoutable.h"

@protocol ASBaselineStackLayoutable <ASStackLayoutable>

/**
 * @abstract The distance from the top of the layoutable object to its baseline
 */
@property (nonatomic, readwrite) CGFloat ascender;

/**
 * @abstract The distance from the bottom of the layoutable object to its baseline
 */
@property (nonatomic, readwrite) CGFloat descender;

@end
