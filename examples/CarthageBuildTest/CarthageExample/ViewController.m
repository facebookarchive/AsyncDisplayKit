//
//  ViewController.m
//  AsyncDisplayKit
//
//  Created by Engin Kurutepe on 23/02/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

@import AsyncDisplayKit;

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGSize screenSize = self.view.bounds.size;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ASTextNode *node = [[ASTextNode alloc] init];
        node.attributedString = [[NSAttributedString alloc] initWithString:@"hello world"];
        [node measure:(CGSize){.width = screenSize.width, .height = CGFLOAT_MAX}];
        node.frame = (CGRect) {.origin = (CGPoint){.x = 100, .y = 100}, .size = node.calculatedSize };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.view addSubview:node.view];
        });
    });
}

@end
