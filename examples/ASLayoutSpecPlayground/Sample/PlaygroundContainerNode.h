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

@interface PlaygroundContainerNode : ASDisplayNode

@property (nonatomic, weak) id<PlaygroundContainerNodeDelegate> delegate;

@end
