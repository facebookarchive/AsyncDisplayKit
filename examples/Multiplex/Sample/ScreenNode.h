//
//  ScreenNode.h
//  Sample
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ScreenNode : ASDisplayNode

@property (nonatomic, strong) ASMultiplexImageNode *imageNode;
@property (nonatomic, strong) ASButtonNode *buttonNode;

- (void)start;
- (void)reload;

@end
