//
//  PlaygroundContainerNode.h
//  Sample
//
//  Created by Hannah Troisi on 3/19/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@protocol PlaygroundContainerNodeDelegate <NSObject>

- (void)relayoutWithSize:(ASSizeRange)size;

@end

@interface PlaygroundContainerNode : ASCellNode

@property (nonatomic, weak) id<PlaygroundContainerNodeDelegate> delegate;

- (instancetype)initWithIndex:(NSUInteger)index;

@end
