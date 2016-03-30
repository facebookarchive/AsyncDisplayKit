//
//  ViewController.m
//  ASAnimatedImage
//
//  Created by Garrett Moon on 3/22/16.
//  Copyright © 2016 Facebook, Inc. All rights reserved.
//

#import "ViewController.h"

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  ASNetworkImageNode *imageNode = [[ASNetworkImageNode alloc] init];
  imageNode.URL = [NSURL URLWithString:@"https://s-media-cache-ak0.pinimg.com/originals/07/44/38/074438e7c75034df2dcf37ba1057803e.gif"];
//  imageNode.URL = [NSURL fileURLWithPath:@"/Users/garrett/Downloads/new-transparent-gif-221.gif"];
  imageNode.frame = self.view.bounds;
  imageNode.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  imageNode.contentMode = UIViewContentModeScaleAspectFit;
  
  [self.view addSubnode:imageNode];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

@end
