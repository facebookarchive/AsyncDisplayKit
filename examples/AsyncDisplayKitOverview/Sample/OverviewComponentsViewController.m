//
//  OverviewComponentsViewController.m
//  Sample
//
//  Created by Michael Schneider on 4/15/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "OverviewComponentsViewController.h"

#import "OverviewDetailViewController.h"
#import "OverviewASCollectionNode.h"
#import "OverviewASTableNode.h"
#import "OverviewASPagerNode.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>


#pragma mark - ASCenterLayoutSpecSizeThatFitsBlock

typedef ASLayoutSpec *(^OverviewDisplayNodeSizeThatFitsBlock)(ASSizeRange constrainedSize);


#pragma mark - OverviewDisplayNodeWithSizeBlock

@interface OverviewDisplayNodeWithSizeBlock : ASDisplayNode<ASLayoutSpecListEntry>

@property (nonatomic, copy) NSString *entryTitle;
@property (nonatomic, copy) NSString *entryDescription;
@property (nonatomic, copy) OverviewDisplayNodeSizeThatFitsBlock sizeThatFitsBlock;

@end

@implementation OverviewDisplayNodeWithSizeBlock

// FIXME: Use new ASDisplayNodeAPI (layoutSpecBlock) API if shipped
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    OverviewDisplayNodeSizeThatFitsBlock block = self.sizeThatFitsBlock;
    if (block != nil) {
        return block(constrainedSize);
    }
    
    return [super layoutSpecThatFits:constrainedSize];
}

@end


#pragma mark - OverviewTitleDescriptionCellNode

@interface OverviewTitleDescriptionCellNode : ASCellNode

@property (nonatomic, strong) ASTextNode *titleNode;
@property (nonatomic, strong) ASTextNode *descriptionNode;

@end

@implementation OverviewTitleDescriptionCellNode

- (instancetype)init
{
    self = [super init];
    if (self == nil) { return self; }
    
    _titleNode = [[ASTextNode alloc] init];
    _descriptionNode = [[ASTextNode alloc] init];
    
    [self addSubnode:_titleNode];
    [self addSubnode:_descriptionNode];
    
    return self;
}

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
    BOOL hasDescription = self.descriptionNode.attributedText.length > 0;
    
    ASStackLayoutSpec *verticalStackLayoutSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
    verticalStackLayoutSpec.alignItems = ASStackLayoutAlignItemsStart;
    verticalStackLayoutSpec.spacing = 5.0;
    verticalStackLayoutSpec.children = hasDescription ? @[self.titleNode, self.descriptionNode] : @[self.titleNode];
    
    return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(10, 16, 10, 10) child:verticalStackLayoutSpec];
}

@end


#pragma mark - OverviewComponentsViewController

@interface OverviewComponentsViewController ()

@property (nonatomic, copy) NSArray *data;
@property (nonatomic, strong) ASTableNode *tableNode;

@end

@implementation OverviewComponentsViewController


#pragma mark - Lifecycle Methods

- (instancetype)init
{
  _tableNode = [ASTableNode new];
  
  self = [super initWithNode:_tableNode];
  
  if (self) {
    _tableNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableNode.delegate =  (id<ASTableDelegate>)self;
    _tableNode.dataSource = (id<ASTableDataSource>)self;
  }
  
  return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"AsyncDisplayKit";
    
    [self setupData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [_tableNode deselectRowAtIndexPath:_tableNode.indexPathForSelectedRow animated:YES];
}


#pragma mark - Data Model

- (void)setupData
{
    OverviewDisplayNodeWithSizeBlock *parentNode = nil;
    ASDisplayNode *childNode = nil;

    
// Setup Nodes Container
// ---------------------------------------------------------------------------------------------------------
    NSMutableArray *mutableNodesContainerData = [NSMutableArray array];
    
#pragma mark ASCollectionNode
    childNode = [OverviewASCollectionNode new];

    parentNode = [self centeringParentNodeWithInset:UIEdgeInsetsZero child:childNode];
    parentNode.entryTitle = @"ASCollectionNode";
    parentNode.entryDescription = @"ASCollectionNode is a node based class that wraps an ASCollectionView. It can be used as a subnode of another node, and provide room for many (great) features and improvements later on.";
    [mutableNodesContainerData addObject:parentNode];
    
#pragma mark ASTableNode
    childNode = [OverviewASTableNode new];
    
    parentNode = [self centeringParentNodeWithInset:UIEdgeInsetsZero child:childNode];
    parentNode.entryTitle = @"ASTableNode";
    parentNode.entryDescription = @"ASTableNode is a node based class that wraps an ASTableView. It can be used as a subnode of another node, and provide room for many (great) features and improvements later on.";
    [mutableNodesContainerData addObject:parentNode];
    
#pragma mark ASPagerNode
    childNode = [OverviewASPagerNode new];
    
    parentNode = [self centeringParentNodeWithInset:UIEdgeInsetsZero child:childNode];
    parentNode.entryTitle = @"ASPagerNode";
    parentNode.entryDescription = @"ASPagerNode is a specialized subclass of ASCollectionNode. Using it allows you to produce a page style UI similar to what you'd create with a UIPageViewController with UIKit. Luckily, the API is quite a bit simpler than UIPageViewController's.";
    [mutableNodesContainerData addObject:parentNode];
    
    
// Setup Nodes
// ---------------------------------------------------------------------------------------------------------
    NSMutableArray *mutableNodesData = [NSMutableArray array];

#pragma mark ASDisplayNode
    ASDisplayNode *displayNode = [self childNode];
    
    parentNode = [self centeringParentNodeWithChild:displayNode];
    parentNode.entryTitle = @"ASDisplayNode";
    parentNode.entryDescription = @"ASDisplayNode is the main view abstraction over UIView and CALayer. It initializes and owns a UIView in the same way UIViews create and own their own backing CALayers.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASButtonNode
    ASButtonNode *buttonNode = [ASButtonNode new];
    
    // Set title for button node with a given font or color. If you pass in nil for font or color the default system
    // font and black as color will be used
    [buttonNode setTitle:@"Button Title Normal" withFont:nil withColor:[UIColor blueColor] forState:UIControlStateNormal];
    [buttonNode setTitle:@"Button Title Highlighted" withFont:[UIFont systemFontOfSize:14] withColor:nil forState:UIControlStateHighlighted];
    [buttonNode addTarget:self action:@selector(buttonPressed:) forControlEvents:ASControlNodeEventTouchUpInside];
    
    parentNode = [self centeringParentNodeWithChild:buttonNode];
    parentNode.entryTitle = @"ASButtonNode";
    parentNode.entryDescription = @"ASButtonNode (a subclass of ASControlNode) supports simple buttons, with multiple states for a text label and an image with a few different layout options. Enables layerBacking for subnodes to significantly lighten main thread impact relative to UIButton (though async preparation is the bigger win).";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASTextNode
    ASTextNode *textNode = [ASTextNode new];
    textNode.attributedText = [[NSAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum varius nisi quis mattis dignissim. Proin convallis odio nec ipsum molestie, in porta quam viverra. Fusce ornare dapibus velit, nec malesuada mauris pretium vitae. Etiam malesuada ligula magna."];
    
    parentNode = [self centeringParentNodeWithChild:textNode];
    parentNode.entryTitle = @"ASTextNode";
    parentNode.entryDescription = @"Like UITextView — built on TextKit with full-featured rich text support.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASEditableTextNode
    ASEditableTextNode *editableTextNode = [ASEditableTextNode new];
    editableTextNode.backgroundColor = [UIColor lightGrayColor];
    editableTextNode.attributedText = [[NSAttributedString alloc] initWithString:@"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vestibulum varius nisi quis mattis dignissim. Proin convallis odio nec ipsum molestie, in porta quam viverra. Fusce ornare dapibus velit, nec malesuada mauris pretium vitae. Etiam malesuada ligula magna."];
    
    parentNode = [self centeringParentNodeWithChild:editableTextNode];
    parentNode.entryTitle = @"ASEditableTextNode";
    parentNode.entryDescription = @"ASEditableTextNode provides a flexible, efficient, and animation-friendly editable text component.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASImageNode
    ASImageNode *imageNode = [ASImageNode new];
    imageNode.image = [UIImage imageNamed:@"image.jpg"];
    
    CGSize imageNetworkImageNodeSize = (CGSize){imageNode.image.size.width / 7, imageNode.image.size.height / 7};
    
    imageNode.style.preferredSize = imageNetworkImageNodeSize;
    
    parentNode = [self centeringParentNodeWithChild:imageNode];
    parentNode.entryTitle = @"ASImageNode";
    parentNode.entryDescription = @"Like UIImageView — decodes images asynchronously.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASNetworkImageNode
    ASNetworkImageNode *networkImageNode = [ASNetworkImageNode new];
    networkImageNode.URL = [NSURL URLWithString:@"http://i.imgur.com/FjOR9kX.jpg"];
    networkImageNode.style.preferredSize = imageNetworkImageNodeSize;
    
    parentNode = [self centeringParentNodeWithChild:networkImageNode];
    parentNode.entryTitle = @"ASNetworkImageNode";
    parentNode.entryDescription = @"ASNetworkImageNode is a simple image node that can download and display an image from the network, with support for a placeholder image.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASMapNode
    ASMapNode *mapNode = [ASMapNode new];
    mapNode.style.preferredSize = CGSizeMake(300.0, 300.0);
    
    // San Francisco
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(37.7749, -122.4194);
    mapNode.region = MKCoordinateRegionMakeWithDistance(coord, 20000, 20000);
    
    parentNode = [self centeringParentNodeWithChild:mapNode];
    parentNode.entryTitle = @"ASMapNode";
    parentNode.entryDescription = @"ASMapNode offers completely asynchronous preparation, automatic preloading, and efficient memory handling. Its standard mode is a fully asynchronous snapshot, with liveMap mode loading automatically triggered by any ASTableView or ASCollectionView; its .liveMap mode can be flipped on with ease (even on a background thread) to provide a cached, fully interactive map when necessary.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASVideoNode
    ASVideoNode *videoNode = [ASVideoNode new];
    videoNode.style.preferredSize = CGSizeMake(300.0, 400.0);
    
    AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:@"http://www.w3schools.com/html/mov_bbb.mp4"]];
    videoNode.asset = asset;
    
    parentNode = [self centeringParentNodeWithChild:videoNode];
    parentNode.entryTitle = @"ASVideoNode";
    parentNode.entryDescription = @"ASVideoNode is a newer class that exposes a relatively full-featured API, and is designed for both efficient and convenient implementation of embedded videos in scrolling views.";
    [mutableNodesData addObject:parentNode];
    
#pragma mark ASScrollNode
    UIImage *scrollNodeImage = [UIImage imageNamed:@"image"];
    
    ASScrollNode *scrollNode = [ASScrollNode new];
    scrollNode.style.preferredSize = CGSizeMake(300.0, 400.0);
    
    UIScrollView *scrollNodeView = scrollNode.view;
    [scrollNodeView addSubview:[[UIImageView alloc] initWithImage:scrollNodeImage]];
    scrollNodeView.contentSize = scrollNodeImage.size;
    
    parentNode = [self centeringParentNodeWithChild:scrollNode];
    parentNode.entryTitle = @"ASScrollNode";
    parentNode.entryDescription = @"Simple node that wraps UIScrollView.";
    [mutableNodesData addObject:parentNode];
    
    
// Layout Specs
// ---------------------------------------------------------------------------------------------------------
    NSMutableArray *mutableLayoutSpecData = [NSMutableArray array];
    
#pragma mark ASInsetLayoutSpec
    childNode = [self childNode];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASInsetLayoutSpec";
    parentNode.entryDescription = @"Applies an inset margin around a component.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(20, 10, 0, 0) child:childNode];
    };
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];
    

#pragma mark ASBackgroundLayoutSpec
    ASDisplayNode *backgroundNode = [ASDisplayNode new];
    backgroundNode.backgroundColor = [UIColor greenColor];
    
    childNode = [self childNode];
    childNode.backgroundColor = [childNode.backgroundColor colorWithAlphaComponent:0.5];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASBackgroundLayoutSpec";
    parentNode.entryDescription = @"Lays out a component, stretching another component behind it as a backdrop.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:childNode background:backgroundNode];
    };
    [parentNode addSubnode:backgroundNode];
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];
    

#pragma mark ASOverlayLayoutSpec
    ASDisplayNode *overlayNode = [ASDisplayNode new];
    overlayNode.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.5];
    
    childNode = [self childNode];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASOverlayLayoutSpec";
    parentNode.entryDescription = @"Lays out a component, stretching another component on top of it as an overlay.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:childNode overlay:overlayNode];
    };
    [parentNode addSubnode:childNode];
    [parentNode addSubnode:overlayNode];
    [mutableLayoutSpecData addObject:parentNode];
    

#pragma mark ASCenterLayoutSpec
    childNode = [self childNode];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASCenterLayoutSpec";
    parentNode.entryDescription = @"Centers a component in the available space.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
                                                          sizingOptions:ASCenterLayoutSpecSizingOptionDefault
                                                                  child:childNode];
    };
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];

#pragma mark ASRatioLayoutSpec
    childNode = [self childNode];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASRatioLayoutSpec";
    parentNode.entryDescription = @"Lays out a component at a fixed aspect ratio. Great for images, gifs and videos.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASRatioLayoutSpec ratioLayoutSpecWithRatio:0.25 child:childNode];
    };
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];

#pragma mark ASRelativeLayoutSpec
    childNode = [self childNode];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASRelativeLayoutSpec";
    parentNode.entryDescription = @"Lays out a component and positions it within the layout bounds according to vertical and horizontal positional specifiers. Similar to the “9-part” image areas, a child can be positioned at any of the 4 corners, or the middle of any of the 4 edges, as well as the center.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASRelativeLayoutSpec relativePositionLayoutSpecWithHorizontalPosition:ASRelativeLayoutSpecPositionEnd
                                                                     verticalPosition:ASRelativeLayoutSpecPositionCenter
                                                                         sizingOption:ASRelativeLayoutSpecSizingOptionDefault
                                                                                child:childNode];
    };
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];

#pragma mark ASAbsoluteLayoutSpec
    childNode = [self childNode];
    // Add a layout position to the child node that the absolute layout spec will pick up and place it on that position
    childNode.style.layoutPosition = CGPointMake(10.0, 10.0);
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"ASAbsoluteLayoutSpec";
    parentNode.entryDescription = @"Allows positioning children at fixed offsets.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        return [ASAbsoluteLayoutSpec absoluteLayoutSpecWithChildren:@[childNode]];
    };
    [parentNode addSubnode:childNode];
    [mutableLayoutSpecData addObject:parentNode];
    

#pragma mark Vertical ASStackLayoutSpec
    ASDisplayNode *childNode1 = [self childNode];
    childNode1.backgroundColor = [UIColor greenColor];
    
    ASDisplayNode *childNode2 = [self childNode];
    childNode2.backgroundColor = [UIColor blueColor];
    
    ASDisplayNode *childNode3 = [self childNode];
    childNode3.backgroundColor = [UIColor yellowColor];
    
    // If we just would add the childrent to the stack layout the layout would be to tall and run out of the edge of
    // the node as 50+50+50 = 150 but the parent node is only 100 height. To prevent that we set flexShrink on 2 of the
    // children to let the stack layout know it should shrink these children in case the layout will run over the edge
    childNode2.style.flexShrink = 1.0;
    childNode3.style.flexShrink = 1.0;
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"Vertical ASStackLayoutSpec";
    parentNode.entryDescription = @"Is based on a simplified version of CSS flexbox. It allows you to stack components vertically or horizontally and specify how they should be flexed and aligned to fit in the available space.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        ASStackLayoutSpec *verticalStackLayoutSpec = [ASStackLayoutSpec verticalStackLayoutSpec];
        verticalStackLayoutSpec.alignItems = ASStackLayoutAlignItemsStart;
        verticalStackLayoutSpec.children = @[childNode1, childNode2, childNode3];
        return verticalStackLayoutSpec;
    };
    [parentNode addSubnode:childNode1];
    [parentNode addSubnode:childNode2];
    [parentNode addSubnode:childNode3];
    [mutableLayoutSpecData addObject:parentNode];
    
#pragma mark Horizontal ASStackLayoutSpec
    childNode1 = [ASDisplayNode new];
    childNode1.style.preferredSize = CGSizeMake(10.0, 20.0);
    childNode1.style.flexGrow = 1.0;
    childNode1.backgroundColor = [UIColor greenColor];
    
    childNode2 = [ASDisplayNode new];
    childNode2.style.preferredSize = CGSizeMake(10.0, 20.0);
    childNode2.style.alignSelf = ASStackLayoutAlignSelfStretch;
    childNode2.backgroundColor = [UIColor blueColor];
    
    childNode3 = [ASDisplayNode new];
    childNode3.style.preferredSize = CGSizeMake(10.0, 20.0);
    childNode3.backgroundColor = [UIColor yellowColor];
    
    parentNode = [self parentNodeWithChild:childNode];
    parentNode.entryTitle = @"Horizontal ASStackLayoutSpec";
    parentNode.entryDescription = @"Is based on a simplified version of CSS flexbox. It allows you to stack components vertically or horizontally and specify how they should be flexed and aligned to fit in the available space.";
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        
        // Create stack alyout spec to layout children
        ASStackLayoutSpec *horizontalStackSpec = [ASStackLayoutSpec horizontalStackLayoutSpec];
        horizontalStackSpec.alignItems = ASStackLayoutAlignItemsStart;
        horizontalStackSpec.children = @[childNode1, childNode2, childNode3];
        horizontalStackSpec.spacing = 5.0; // Spacing between children
        
        // Layout the stack layout with 100% width and 100% height of the parent node
        horizontalStackSpec.style.height = ASDimensionMakeWithFraction(1.0);
        horizontalStackSpec.style.width = ASDimensionMakeWithFraction(1.0);
        
        // Add a bit of inset
        return [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(0.0, 5.0, 0.0, 5.0) child:horizontalStackSpec];
    };
    [parentNode addSubnode:childNode1];
    [parentNode addSubnode:childNode2];
    [parentNode addSubnode:childNode3];
    [mutableLayoutSpecData addObject:parentNode];
    

// Setup Data
// ---------------------------------------------------------------------------------------------------------
    NSMutableArray *mutableData = [NSMutableArray array];
    [mutableData addObject:@{@"title" : @"Node Containers", @"data" : mutableNodesContainerData}];
    [mutableData addObject:@{@"title" : @"Nodes", @"data" : mutableNodesData}];
    [mutableData addObject:@{@"title" : @"Layout Specs", @"data" : [mutableLayoutSpecData copy]}];
    self.data  = mutableData;
}

#pragma mark - Parent / Child Helper

- (OverviewDisplayNodeWithSizeBlock *)parentNodeWithChild:(ASDisplayNode *)child
{
    OverviewDisplayNodeWithSizeBlock *parentNode = [OverviewDisplayNodeWithSizeBlock new];
    parentNode.style.preferredSize = CGSizeMake(100, 100);
    parentNode.backgroundColor = [UIColor redColor];
    return parentNode;
}

- (OverviewDisplayNodeWithSizeBlock *)centeringParentNodeWithChild:(ASDisplayNode *)child
{
    return [self centeringParentNodeWithInset:UIEdgeInsetsMake(10, 10, 10, 10) child:child];
}

- (OverviewDisplayNodeWithSizeBlock *)centeringParentNodeWithInset:(UIEdgeInsets)insets child:(ASDisplayNode *)child
{
    OverviewDisplayNodeWithSizeBlock *parentNode = [OverviewDisplayNodeWithSizeBlock new];
    [parentNode addSubnode:child];
    parentNode.sizeThatFitsBlock = ^ASLayoutSpec *(ASSizeRange constrainedSize) {
        ASCenterLayoutSpec *centerLayoutSpec = [ASCenterLayoutSpec centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY sizingOptions:ASCenterLayoutSpecSizingOptionDefault child:child];
        return [ASInsetLayoutSpec insetLayoutSpecWithInsets:insets child:centerLayoutSpec];
    };
    return parentNode;
}

- (ASDisplayNode *)childNode
{
    ASDisplayNode *childNode = [ASDisplayNode new];
    childNode.style.preferredSize = CGSizeMake(50, 50);
    childNode.backgroundColor = [UIColor blueColor];
    return childNode;
}

#pragma mark - Actions

- (void)buttonPressed:(ASButtonNode *)buttonNode
{
    NSLog(@"Button Pressed");
}

#pragma mark - <ASTableDataSource / ASTableDelegate>

- (NSInteger)numberOfSectionsInTableNode:(ASTableNode *)tableNode
{
    return self.data.count;
}

- (nullable NSString *)tableNode:(ASTableNode *)tableNode titleForHeaderInSection:(NSInteger)section
{
    return self.data[section][@"title"];
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
    return [self.data[section][@"data"] count];
}

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // You should get the node or data you want to pass to the cell node outside of the ASCellNodeBlock
    ASDisplayNode<ASLayoutSpecListEntry> *node = self.data[indexPath.section][@"data"][indexPath.row];
    return ^{
        OverviewTitleDescriptionCellNode *cellNode = [OverviewTitleDescriptionCellNode new];
        
        NSDictionary *titleNodeAttributes = @{
            NSFontAttributeName : [UIFont boldSystemFontOfSize:14.0],
            NSForegroundColorAttributeName : [UIColor blackColor]
        };
        cellNode.titleNode.attributedText = [[NSAttributedString alloc] initWithString:node.entryTitle attributes:titleNodeAttributes];
        
        if (node.entryDescription) {
            NSDictionary *descriptionNodeAttributes = @{NSForegroundColorAttributeName : [UIColor lightGrayColor]};
            cellNode.descriptionNode.attributedText = [[NSAttributedString alloc] initWithString:node.entryDescription attributes:descriptionNodeAttributes];
        }
        
        return cellNode;
    };
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ASDisplayNode *node = self.data[indexPath.section][@"data"][indexPath.row];
    OverviewDetailViewController *detail = [[OverviewDetailViewController alloc] initWithNode:node];
    [self.navigationController pushViewController:detail animated:YES];
}

@end
