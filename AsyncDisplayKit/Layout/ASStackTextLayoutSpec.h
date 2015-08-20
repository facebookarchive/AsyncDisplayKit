//
//  ASStackTextLayoutSpec.h
//  AsyncDisplayKit
//
//  Created by ricky cancro on 8/19/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASStackLayoutSpec.h>

/** Orientation of children along cross axis */
typedef NS_ENUM(NSUInteger, ASStackTextLayoutBaselineAlignment) {
    ASStackTextLayoutBaselineAlignmentNone,
    /** Children align along the first baseline of the stack. Only available for horizontal stack nodes */
    ASStackTextLayoutBaselineAlignmentFirst,
    /** Children align along the last baseline of the stack. Only available for horizontal stack nodes */
    ASStackTextLayoutBaselineAlignmentLast,
};


typedef struct {
    /** Specifies the direction children are stacked in. */
    ASStackLayoutSpecStyle stackLayoutStyle;
    
    ASStackTextLayoutBaselineAlignment baselineAlignment;
} ASStackTextLayoutSpecStyle;

@interface ASStackTextLayoutSpec : ASLayoutSpec

/**
 @param style Specifies how children are laid out.
 @param children ASLayoutable children to be positioned.
 */
+ (instancetype)newWithStyle:(ASStackTextLayoutSpecStyle)style children:(NSArray *)children;

@end
