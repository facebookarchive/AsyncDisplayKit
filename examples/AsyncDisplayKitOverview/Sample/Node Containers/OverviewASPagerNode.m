//
//  OverviewASPagerNode.m
//  AsyncDisplayKitOverview
//
//  Created by Michael Schneider on 4/17/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OverviewASPagerNode.h"

#pragma mark - Helper

static UIColor *OverViewASPagerNodeRandomColor() {
    CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
    CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
    CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
}


#pragma mark - OverviewASPageNode

@interface OverviewASPageNode : ASCellNode @end

@implementation OverviewASPageNode

- (ASLayout *)calculateLayoutThatFits:(ASSizeRange)constrainedSize
{
    return [ASLayout layoutWithLayoutableObject:self
                           constrainedSizeRange:constrainedSize
                                           size:constrainedSize.max];
}

@end


#pragma mark - OverviewASPagerNode

@interface OverviewASPagerNode () <ASPagerNodeDataSource>
@property (nonatomic, strong) ASPagerNode *node;
@property (nonatomic, copy) NSArray *data;
@end

@implementation OverviewASPagerNode

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _node = [ASPagerNode new];
    _node.dataSource = self;
    [self addSubnode:_node];
    
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    _node.sizeRange = ASRelativeSizeRangeMakeWithExactCGSize(constrainedSize.max);
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[_node]];
}

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode
{
    return 4;
}

- (ASCellNodeBlock)pagerNode:(ASPagerNode *)pagerNode nodeBlockAtIndex:(NSInteger)index
{
    return ^{
        ASCellNode *cellNode = [OverviewASPageNode new];
        cellNode.backgroundColor = OverViewASPagerNodeRandomColor();
        return cellNode;
    };
}


@end
