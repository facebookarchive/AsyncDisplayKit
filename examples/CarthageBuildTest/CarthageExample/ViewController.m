//
//  ViewController.m
//  CarthageExample
//
//  Created by Engin Kurutepe on 23/02/16.
//  Copyright © 2016 Engin Kurutepe. All rights reserved.
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
