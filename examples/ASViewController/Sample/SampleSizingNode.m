//
//  SampleSizingNode.m
//  Sample
//
//  Created by Michael Schneider on 11/10/16.
//  Copyright © 2016 AsyncDisplayKit. All rights reserved.
//

#import "SampleSizingNode.h"

@interface SampleSizingNodeSubnode : ASDisplayNode
@property (strong, nonatomic) ASTextNode *textNode;
@end

@implementation SampleSizingNodeSubnode

- (void)layout
{
    [super layout];
    
    // Manual layout after the normal layout engine did it's job
    // Calculated size can be used after the layout spec pass happened
    //self.textNode.frame = CGRectMake(self.textNode.frame.origin.x, self.textNode.frame.origin.y, self.textNode.calculatedSize.width, 20);
}

@end

@interface SampleSizingNode ()
@property (nonatomic, assign) NSInteger state;

@property (nonatomic, strong) SampleSizingNodeSubnode *subnode;
@property (nonatomic, strong) ASTextNode *textNode;
@property (nonatomic, strong) ASNetworkImageNode *imageNode;
@end

@implementation SampleSizingNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.automaticallyManagesSubnodes = YES;
        
        self.backgroundColor = [UIColor greenColor];
        
        _textNode = [ASTextNode new];
        _textNode.backgroundColor = [UIColor blueColor];
        
        _imageNode = [ASNetworkImageNode new];
        _imageNode.URL = [NSURL URLWithString:@"https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/Mont_Blanc_oct_2004.JPG/280px-Mont_Blanc_oct_2004.JPG"];
        _imageNode.backgroundColor = [UIColor brownColor];
        _imageNode.needsDisplayOnBoundsChange = YES;
        _imageNode.style.height = ASDimensionMakeWithFraction(1.0);
        _imageNode.style.width = ASDimensionMake(50.0);
        
        
        _subnode = [SampleSizingNodeSubnode new];
        _subnode.textNode = _textNode;
        _subnode.backgroundColor = [UIColor redColor];
        _subnode.automaticallyManagesSubnodes = YES;
        
        // Layout description via layoutSpecBlock
        __weak __typeof(self) weakSelf = self;
        _subnode.layoutSpecBlock = ^ASLayoutSpec *(__kindof ASDisplayNode * _Nonnull node, ASSizeRange constrainedSize) {
            
            UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
            ASInsetLayoutSpec *textInsetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:weakSelf.textNode];
            textInsetSpec.style.flexShrink = 1.0;
            
            return [ASStackLayoutSpec
                    stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                    spacing:0.0
                    justifyContent:ASStackLayoutJustifyContentStart
                    alignItems:ASStackLayoutAlignItemsStart
                    children:@[weakSelf.imageNode, textInsetSpec]];
            //return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithSizing:ASAbsoluteLayoutSpecSizingSizeToFit children:@[_imageNode, insetSpec]];
        };
        
        _state = 0;
    }
    return self;
}

- (void)didLoad
{
    [super didLoad];
    
    
    // Initial state
    self.state = 0;
    
    // Simulate a state change of the node
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.state = 1;
    });
}

#pragma mark - State Management

- (void)setState:(NSInteger)state
{
    _state = state;
    
    // Set text based on state
    NSString *text = state == 0 ? @"Bla Bla" : @"Bla Blaa sd fkj as;l dkf";
    self.textNode.attributedText = [[NSAttributedString alloc] initWithString:text];
    
    //self.imageNode.style.width = state == 0 ? ASDimensionMake(30.0) : ASDimensionMake(50.0);
    
    // Let the root node know there can be a size change happened. If we will not call this the text node will just
    // use it's own bounds and layout again in the next layout pass what can result in truncation
    [self invalidateCalculatedLayoutSizingBlaBla];
}

// Invalidates the current layout and bubbles up the setNeedsLayout call to the root node. The root node will inform
// the sizing delegate that a size change did happen and it's up to it to decide if the bounds of the root node should
// change based on this request or not. If no change happened the layout will happen in all subnodes based on the current
// set bounds
- (void)invalidateCalculatedLayoutSizingBlaBla
{
    // Invalidate the layout for now and bubble it up until the root node to let the size provider know that
    // that a size change could have happened
    // --> Do we even need to invalidate the layout?
    [self setNeedsLayout];
    
    // If someone calls `invalidateBlaBla TBD` we have to inform the sizing delegate of the root node to be able
    // to let them now that a size change happened and it needs to calculate a new layout / size for this node hierarchy
    /*if ([self.sizingDelegate respondsToSelector:@selector(displayNodeDidInvalidateSize:)]) {
        [self.sizingDelegate performSelector:@selector(displayNodeDidInvalidateSize:) withObject:self];
    }*/
    [self invalidateSize];
}

#pragma mark - ASDisplayNode

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    // Layout description based on state
   // UIEdgeInsets insets = UIEdgeInsetsMake(10, 10, 10, 10);
   // return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:_textNode];
    
    //return [ASWrapperLayoutSpec wrapperWithLayoutElement:self.subnode];
    return [ASCenterLayoutSpec
            centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
            sizingOptions:ASCenterLayoutSpecSizingOptionDefault
            child:self.subnode];
}

- (void)layout
{
    [super layout];
    
    // Layout after the official layout pass happened
    //self.subnode.frame = CGRectMake(self.subnode.frame.origin.x, self.subnode.frame.origin.y, 100, self.calculatedSize.height);
}


@end
