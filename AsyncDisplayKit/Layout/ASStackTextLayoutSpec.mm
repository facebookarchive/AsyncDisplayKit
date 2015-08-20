//
//  ASStackTextLayoutSpec.m
//  AsyncDisplayKit
//
//  Created by ricky cancro on 8/19/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ASStackTextLayoutSpec.h"
#import "ASStackLayoutable.h"

#import <numeric>
#import <vector>

#import "ASBaseDefines.h"
#import "ASInternalHelpers.h"

#import "ASLayoutSpecUtilities.h"
#import "ASStackLayoutSpecUtilities.h"
#import "ASStackPositionedLayout.h"
#import "ASStackUnpositionedLayout.h"
#import "ASThread.h"

static CGFloat baselineForItem(const ASStackTextLayoutSpecStyle &style,
                               const ASLayout *layout) {
    
    __weak id<ASStackTextLayoutable> textChild = (id<ASStackTextLayoutable>) layout.layoutableObject;
    switch (style.baselineAlignment) {
        case ASStackTextLayoutBaselineAlignmentNone:
            return 0;
        case ASStackTextLayoutBaselineAlignmentFirst:
            return textChild.ascender;
        case ASStackTextLayoutBaselineAlignmentLast:
            return textChild.descender;
    }
    
}

static CGFloat baselineOffset(const ASStackTextLayoutSpecStyle &style,
                              const ASLayout *l,
                              const CGFloat maxBaseline)
{
    switch (style.baselineAlignment) {
        case ASStackTextLayoutBaselineAlignmentFirst:
        case ASStackTextLayoutBaselineAlignmentLast:
            return maxBaseline - baselineForItem(style, l);
        case ASStackTextLayoutBaselineAlignmentNone:
            return 0;
    }
}


@implementation ASStackTextLayoutSpec
{
    ASStackTextLayoutSpecStyle _textStyle;
    std::vector<id<ASStackTextLayoutable>> _children;
    std::vector<id<ASStackLayoutable>> _stackChildren;
    ASDN::RecursiveMutex _propertyLock;
}

+ (instancetype)newWithStyle:(ASStackTextLayoutSpecStyle)style children:(NSArray *)children
{
    ASDisplayNodeAssert(style.stackLayoutStyle.direction == ASStackLayoutDirectionHorizontal && style.baselineAlignment != ASStackTextLayoutBaselineAlignmentNone, @"if you don't need baseline alignment, use ASStackLayoutSpec");
    
    ASStackTextLayoutSpec *spec = [super new];
    if (spec) {
        spec->_textStyle = style;
        spec->_children = std::vector<id<ASStackTextLayoutable>>();
        for (id<ASStackTextLayoutable> child in children) {
            ASDisplayNodeAssert([child conformsToProtocol:@protocol(ASStackTextLayoutable)], @"child must conform to ASStackLayoutable");
            
            spec->_children.push_back(child);
            spec->_stackChildren.push_back(child);
        }
    }
    return spec;
}

+ (instancetype)new
{
    ASDISPLAYNODE_NOT_DESIGNATED_INITIALIZER();
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
    ASStackLayoutSpecStyle stackStyle = _textStyle.stackLayoutStyle;
    
    
    const auto unpositionedLayout = ASStackUnpositionedLayout::compute(_stackChildren, stackStyle, constrainedSize);
    const auto positionedLayout = ASStackPositionedLayout::compute(unpositionedLayout, stackStyle, constrainedSize);
    
    // Alter the positioned layouts to include baselines
    const auto baselineIt = std::max_element(positionedLayout.sublayouts.begin(), positionedLayout.sublayouts.end(), [&](const ASLayout *a, const ASLayout *b){
        return baselineForItem(_textStyle, a) < baselineForItem(_textStyle, b);
    });
    const CGFloat maxBaseline = baselineIt == positionedLayout.sublayouts.end() ? 0 : baselineForItem(_textStyle, *baselineIt);
    
    CGPoint p = CGPointZero;
    BOOL first = YES;
    auto stackedChildren = AS::map(positionedLayout.sublayouts, [&](ASLayout *l) -> ASLayout *{
        __weak id<ASStackTextLayoutable> textChild = (id<ASStackTextLayoutable>) l.layoutableObject;
        if (first) {
            p = l.position;
        }
        first = NO;
        
        if (stackStyle.direction == ASStackLayoutDirectionHorizontal) {
            l.position = p + CGPointMake(0, baselineOffset(_textStyle, l, maxBaseline));
        }
        
        CGFloat spacingAfterBaseline = (stackStyle.direction == ASStackLayoutDirectionVertical) ? textChild.descender : 0;
        p = p + directionPoint(stackStyle.direction, stackDimension(stackStyle.direction, l.size) + [(id<ASStackLayoutable>)l.layoutableObject spacingAfter] + spacingAfterBaseline, 0);
        
        return l;
    });
    
    const ASStackPositionedLayout alteredPositionedLayouts = {stackedChildren, positionedLayout.crossSize};
    const CGSize finalSize = directionSize(stackStyle.direction, unpositionedLayout.stackDimensionSum, alteredPositionedLayouts.crossSize);
    
    NSArray *sublayouts = [NSArray arrayWithObjects:&alteredPositionedLayouts.sublayouts[0] count:alteredPositionedLayouts.sublayouts.size()];
    
    
    return [ASLayout newWithLayoutableObject:self
                                        size:ASSizeRangeClamp(constrainedSize, finalSize)
                                  sublayouts:sublayouts];
}
@end
