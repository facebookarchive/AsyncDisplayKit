//
//  DetailViewController.m
//  Sample
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

#import "DetailViewController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "DetailRootNode.h"
#import "SampleSizingNode.h"

@interface DetailViewController ()// <ASDisplayNodeSizingDelegate>
@property (strong, nonatomic) SampleSizingNode *sizingNode;

@property (strong, nonatomic) ASNetworkImageNode *imageNode;
@property (strong, nonatomic) ASButtonNode *buttonNode;

@end

@implementation DetailViewController

#pragma mark - Lifecycle

- (instancetype)initWithNode:(DetailRootNode *)node
{
    self = [super initWithNode:node];
    
    // Set the sizing delegate of the root node to the container
    _sizingNode = [SampleSizingNode new];
    _sizingNode.autoresizingMask = UIViewAutoresizingNone;
    //_sizingNode.sizingDelegate = self;
    
    _imageNode = [ASNetworkImageNode new];
    _imageNode.needsDisplayOnBoundsChange = YES;
    _imageNode.backgroundColor = [UIColor brownColor];
    _imageNode.style.preferredSize = CGSizeMake(100, 100);
    _imageNode.URL = [NSURL URLWithString:@"http://www.classicwings-bavaria.com/bavarian-pictures/chitty-chitty-bang-bang-castle.jpg"];
    
    _buttonNode = [ASButtonNode new];
    _buttonNode.backgroundColor = [UIColor yellowColor];
    [_buttonNode setTitle:@"Some Title" withFont:nil withColor:nil forState:ASControlStateNormal];
    [_buttonNode setTitle:@"Some Bla" withFont:nil withColor:[UIColor orangeColor] forState:ASControlStateHighlighted];
    [_buttonNode addTarget:self action:@selector(buttonAction:) forControlEvents:ASControlNodeEventTouchUpInside];
    //_buttonNode.sizingDelegate = self;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view addSubnode:self.sizingNode];
    [self.view addSubnode:self.imageNode];
    [self.view addSubnode:self.buttonNode];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Initial size of sizing node
    //self.sizingNode.frame = CGRectMake(100, 100, 50, 50);
    
    //[self displayNodeDidInvalidateSize:self.buttonNode];
    
    // Initial size for image node
//    self.imageNode.frame = CGRectMake(50, 70, 100, 100);
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        self.imageNode.frame = CGRectMake(50, 70, 70, 50);
//        //[self.imageNode setNeedsLayout];
//        //[self.imageNode setNeedsDisplay];
//    });
    
    // Start some timer  to chang ethe size randomly
    [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        //[self updateNodeLayoutRandom];
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    // Updat the sizing for the button node
    [self updateButtonNodeLayout];
    
    // Update the sizing node layout
    [self updateNodeLayout];
}

#pragma mark - Update the node based on the new size

- (void)updateButtonNodeLayout
{
    [self.buttonNode sizeToFit];
    self.buttonNode.frame = CGRectMake((self.view.bounds.size.width - self.buttonNode.bounds.size.width) / 2.0,
                                       100,
                                       self.buttonNode.bounds.size.width,
                                       self.buttonNode.bounds.size.height);

    //CGSize s = [self.buttonNode sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
    //self.buttonNode.frame = CGRectMake(100, 100, s.width, s.height);
}

// The sizing delegate will get callbacks if the size did invalidate of the display node. It's the job of the delegate
// to get the new size from the display node and update the frame based on the returned size
//- (void)displayNodeDidInvalidateSize:(ASDisplayNode *)displayNode
//{
//    if (displayNode == self.buttonNode) {
//        [self updateButtonNodeLayout];
//        return;
//    }
//    
//    [self updateNodeLayout];
//    
//    /*dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self updateNodeLayoutRandom];
//    });*/
//    
//   /*[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
//        [self updateNodeLayoutRandom];
//    }];*/
//}

- (void)updateNodeLayout
{
    // Adjust the layout on the new layout
    //return;
    // Use the bounds of the view and get the fitting size
    // This does not have any side effects, but can be called on the main thread without any problems
    CGSize size = [self.sizingNode sizeThatFits:CGSizeMake(INFINITY, 100.0)];
    //size.width -= 10;
    //[self.sizingNode setNeedsLayout];
    self.sizingNode.frame = CGRectMake((CGRectGetWidth(self.view.bounds) - size.width) / 2.0,
                                       (CGRectGetHeight(self.view.bounds) - size.height) / 2.0,
                                       size.width,
                                       size.height);
    
    //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Decrease the frame a bit
        self.sizingNode.frame = CGRectInset(self.sizingNode.frame, 10, 10);
    //});
}

- (void)updateNodeLayoutRandom
{
    CGRect bounds = self.view.bounds;
    
    // Pick a randome width and height and set the frame of the node
    CGSize size = CGSizeZero;
    size.width = arc4random_uniform(CGRectGetWidth(bounds));
    size.height = arc4random_uniform(CGRectGetHeight(bounds));
    
    //[self.sizingNode setNeedsLayout];
    self.sizingNode.frame = CGRectMake((CGRectGetWidth(bounds) - size.width) / 2.0,
                                       (CGRectGetHeight(bounds) - size.height) / 2.0,
                                       size.width,
                                       size.height);

}

#pragma mark - 

- (void)buttonAction:(id)sender
{
    NSLog(@"Button Sender");
}

#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.node.collectionNode.view.collectionViewLayout invalidateLayout];
}


@end
