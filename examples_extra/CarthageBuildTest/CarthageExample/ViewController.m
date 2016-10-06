//
//  ViewController.m
//  Sample
//
//  Created by Engin Kurutepe on 23/02/16.
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

#import "ViewController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGSize screenSize = self.view.bounds.size;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ASTextNode *node = [[ASTextNode alloc] init];
        node.attributedText = [[NSAttributedString alloc] initWithString:@"hello world"];
        [node layoutThatFits:ASSizeRangeMake(CGSizeZero, (CGSize){.width = screenSize.width, .height = CGFLOAT_MAX})];
        node.frame = (CGRect) {.origin = (CGPoint){.x = 100, .y = 100}, .size = node.calculatedSize };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view addSubview:node.view];
        });
    });
}

@end
