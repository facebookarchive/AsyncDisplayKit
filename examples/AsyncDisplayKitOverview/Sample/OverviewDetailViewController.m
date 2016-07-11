//
//  OverviewDetailViewController.m
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
