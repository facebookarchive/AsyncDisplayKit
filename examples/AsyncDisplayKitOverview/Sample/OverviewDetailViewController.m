//
//  OverviewDetailViewController.m
//  AsyncDisplayKitOverview
//
//  Created by Michael Schneider on 4/15/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "OverviewDetailViewController.h"

@interface OverviewDetailViewController ()
@property (nonatomic, strong) ASDisplayNode *node;
@end

@implementation OverviewDetailViewController

#pragma mark - Lifecycle

- (instancetype)initWithNode:(ASDisplayNode *)node
{
    self = [super initWithNibName:nil bundle:nil];
    if (self == nil) { return self; }
    _node = node;
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubnode:self.node];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Center node frame
    CGRect bounds = self.view.bounds;
    CGSize nodeSize = self.node.preferredFrameSize;
    if (CGSizeEqualToSize(nodeSize, CGSizeZero)) {
        nodeSize = self.view.bounds.size;
    }
    self.node.frame = CGRectMake(CGRectGetMidX(bounds) - (nodeSize.width / 2.0), CGRectGetMidY(bounds) - (nodeSize.height / 2.0), nodeSize.width, nodeSize.height);
    [self.node measure:self.node.bounds.size];
}

@end
