//
//  ASRelativePositionLayoutSpec.m
//  Pods
//
//  Created by Samuel Stow on 12/31/15.
//
//

#import "ASRelativePositionLayoutSpec.h"

#import "ASInternalHelpers.h"
#import "ASLayout.h"

@implementation ASRelativePositionLayoutSpec

- initWithHorizontalPosition:(ASRelativePositionLayoutSpecPosition)horizontalPosition verticalPosition:(ASRelativePositionLayoutSpecPosition)verticalPosition sizingOption:(ASRelativePositionLayoutSpecSizingOption)sizingOption child:(id<ASLayoutable>)child
{
    if (!(self = [super init])) {
        return nil;
    }
    ASDisplayNodeAssertNotNil(child, @"Child cannot be nil");
    _horizontalPosition = horizontalPosition;
    _verticalPosition = verticalPosition;
    _sizingOption = sizingOption;
    [self setChild:child];
    return self;
}

+ (instancetype)relativePositionLayoutSpecWithHorizontalPosition:(ASRelativePositionLayoutSpecPosition)horizontalPosition verticalPosition:(ASRelativePositionLayoutSpecPosition)verticalPosition sizingOption:(ASRelativePositionLayoutSpecSizingOption)sizingOption child:(id<ASLayoutable>)child
{
    return [[self alloc] initWithHorizontalPosition:horizontalPosition verticalPosition:verticalPosition sizingOption:sizingOption child:child];
}

- (void)setHorizontalPosition:(ASRelativePositionLayoutSpecPosition)horizontalPosition
{
    ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
    _horizontalPosition = horizontalPosition;
}

- (void)setVerticalPosition:(ASRelativePositionLayoutSpecPosition)verticalPosition {
    ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
    _verticalPosition = verticalPosition;
}

- (void)setSizingOption:(ASRelativePositionLayoutSpecSizingOption)sizingOption
{
    ASDisplayNodeAssert(self.isMutable, @"Cannot set properties when layout spec is not mutable");
    _sizingOption = sizingOption;
}

- (ASLayout *)measureWithSizeRange:(ASSizeRange)constrainedSize
{
    CGSize size = {
        constrainedSize.max.width,
        constrainedSize.max.height
    };
    
    BOOL reduceWidth = (_horizontalPosition & ASRelativePositionLayoutSpecPositionCenter) != 0 ||
    (_horizontalPosition & ASRelativePositionLayoutSpecPositionMax) != 0;
    
    BOOL reduceHeight = (_verticalPosition & ASRelativePositionLayoutSpecPositionCenter) != 0 ||
    (_verticalPosition & ASRelativePositionLayoutSpecPositionMax) != 0;
    
    // Layout the child
    const CGSize minChildSize = {
        reduceWidth ? 0 : constrainedSize.min.width,
        reduceHeight ? 0 : constrainedSize.min.height,
    };
    ASLayout *sublayout = [self.child measureWithSizeRange:ASSizeRangeMake(minChildSize, constrainedSize.max)];
    
    // If we have an undetermined height or width, use the child size to define the layout
    // size
    size = ASSizeRangeClamp(constrainedSize, {
        isfinite(size.width) == NO ? sublayout.size.width : size.width,
        isfinite(size.height) == NO ? sublayout.size.height : size.height
    });
    
    // If minimum size options are set, attempt to shrink the size to the size of the child
    size = ASSizeRangeClamp(constrainedSize, {
        MIN(size.width, (_sizingOption & ASRelativePositionLayoutSpecSizingOptionOptionMinimumX) != 0 ? sublayout.size.width : size.width),
        MIN(size.height, (_sizingOption & ASRelativePositionLayoutSpecSizingOptionOptionMinimumY) != 0 ? sublayout.size.height : size.height)
    });
    
    // Compute the centered postion for the child
    CGFloat xPosition = [self proportionOfAxisForAxisPosition:_horizontalPosition];
    CGFloat yPosition = [self proportionOfAxisForAxisPosition:_verticalPosition];
    
    sublayout.position = {
        ASRoundPixelValue((size.width - sublayout.size.width) * xPosition),
        ASRoundPixelValue((size.height - sublayout.size.height) * yPosition)
    };
    
    return [ASLayout layoutWithLayoutableObject:self size:size sublayouts:@[sublayout]];
}

- (void)setChildren:(NSArray *)children
{
    ASDisplayNodeAssert(NO, @"not supported by this layout spec");
}

- (NSArray *)children
{
    ASDisplayNodeAssert(NO, @"not supported by this layout spec");
    return nil;
}

- (CGFloat)proportionOfAxisForAxisPosition:(ASRelativePositionLayoutSpecPosition)position {
    if ((position & ASRelativePositionLayoutSpecPositionCenter) != 0) {
        return 0.5f;
    } else if ((position & ASRelativePositionLayoutSpecPositionMax) != 0) {
        return 1.0f;
    } else {
        return 0.0f;
    }
}

@end