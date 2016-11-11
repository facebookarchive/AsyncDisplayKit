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

@interface DetailViewController ()
@property (strong, nonatomic) SampleSizingNode *sizingNode;

@end

@implementation DetailViewController

#pragma mark - Lifecycle

- (instancetype)initWithNode:(DetailRootNode *)node
{
    self = [super initWithNode:node];
    
    // Set the sizing delegate of the root node to the container
    self.sizingNode = [SampleSizingNode new];
    self.sizingNode.autoresizingMask = UIViewAutoresizingNone;
    self.sizingNode.delegate = self;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.view addSubnode:self.sizingNode];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Initial size of sizing node
    self.sizingNode.frame = CGRectMake(100, 100, 50, 50);
    
    // Start some timer  to chang ethe size randomly
    [NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        //[self updateNodeLayoutRandom];
    }];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    [self updateNodeLayout];
}

#pragma mark - Update the node based on the new size

// The sizing delegate will get callbacks if the size did invalidate of the display node. It's the job of the delegate
// to get the new size from the display node and update the frame based on the returned size
- (void)displayNodeDidInvalidateSize:(ASDisplayNode *)displayNode
{
    [self updateNodeLayout];
    
    /*dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self updateNodeLayoutRandom];
    });*/
    
   /*[NSTimer scheduledTimerWithTimeInterval:2.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self updateNodeLayoutRandom];
    }];*/
}

- (void)updateNodeLayout
{
    // Adjust the layout on the new layout
    //return;
    // Use the bounds of the view and get the fitting size
    // This does not have any side effects, but can be called on the main thread without any problems
    CGSize size = [self.sizingNode sizeThatFits:CGSizeMake(CGFLOAT_MAX, 100.0)];
    //size.width -= 10;
    //[self.sizingNode setNeedsLayout];
    self.sizingNode.frame = CGRectMake((self.view.bounds.size.width - size.width) / 2.0,
                                       (self.view.bounds.size.height - size.height) / 2.0,
                                       size.width, size.height);
    
    //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.sizingNode.frame = CGRectInset(self.sizingNode.frame, 10, 10);
    //});
}

- (void)updateNodeLayoutRandom
{
    // Pick a randome width and height and set the frame of the node
    CGSize size = CGSizeZero;
    size.width = arc4random_uniform(self.view.bounds.size.width);
    size.height = arc4random_uniform(self.view.bounds.size.height);
    
    //[self.sizingNode setNeedsLayout];
    self.sizingNode.frame = CGRectMake((self.view.bounds.size.width - size.width) / 2.0,
                                       (self.view.bounds.size.height - size.height) / 2.0,
                                       size.width, size.height);

}


#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.node.collectionNode.view.collectionViewLayout invalidateLayout];
}


@end
