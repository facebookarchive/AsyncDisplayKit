//
//  ASPagerNode.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 12/7/15.
//  Copyright © 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionNode.h>

@protocol ASPagerNodeDataSource;

@interface ASPagerNode : ASCollectionNode

@property (weak, nonatomic) id<ASPagerNodeDataSource> dataSource;

- (void)reloadData;

- (void)setTuningParameters:(ASRangeTuningParameters)tuningParameters forRangeType:(ASLayoutRangeType)rangeType;

@end

@protocol ASPagerNodeDataSource <NSObject>

- (NSInteger)numberOfPagesInPagerNode:(ASPagerNode *)pagerNode;

- (ASCellNode *)pagerNode:(ASPagerNode *)pagerNode nodeAtIndex:(NSInteger)index;

@end