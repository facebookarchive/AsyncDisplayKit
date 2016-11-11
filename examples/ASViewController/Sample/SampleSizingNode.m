//
//  SampleSizingNode.m
//  Sample
//
//  Created by Michael Schneider on 11/10/16.
//  Copyright © 2016 AsyncDisplayKit. All rights reserved.
//

#import "SampleSizingNode.h"

@interface SampleSizingNode ()
@property (nonatomic, strong) ASDisplayNode *subnode;
@property (nonatomic, assign) NSInteger state;

@property (nonatomic, strong) ASTextNode *textNode;
@end

@implementation SampleSizingNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.automaticallyManagesSubnodes = YES;
        
        //_subnode = [ASDisplayNode new];
        //_subnode.backgroundColor = [UIColor redColor];
        
        _textNode = [ASTextNode new];
        _textNode.backgroundColor = [UIColor blueColor];
        _textNode.autoresizingMask = UIViewAutoresizingNone;
        
        _state = 0;
    }
    return self;
}

- (void)didLoad
{
    [super didLoad];
    
    [self stateChanged];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.state = 1;
    });
}

#pragma mark - State Management

- (void)setState:(NSInteger)state
{
    _state = state;
    [self stateChanged];
}

- (void)stateChanged
{
    NSString *text = self.state == 0 ? @"Bla Bla" : @"Bla Blaa sd fkj as;l dkf";
    self.textNode.attributedText = [[NSAttributedString alloc] initWithString:text];
    
    // Invalidate the layout for now and bubble it up until the root node to let the size provider know that
    // that a size change happened
    [self setNeedsLayout];
    
    // If someone calls `setNeedsLayout` we have to inform the sizing delegate of the root node to be able
    // to let them now that a size change happened
    if ([self.delegate respondsToSelector:@selector(displayNodeDidInvalidateSize:)]) {
        [self.delegate performSelector:@selector(displayNodeDidInvalidateSize:) withObject:self];
    }
}


#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    // Layout description based on state
    //self.subnode.style.preferredSize = constrainedSize.max;
    UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_textNode];
}


@end
