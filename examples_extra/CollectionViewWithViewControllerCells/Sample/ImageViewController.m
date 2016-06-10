//
//  ImageViewController.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//


#import "ImageViewController.h"

@interface ImageViewController ()
@property (nonatomic) UIImageView *imageView;
@end

@implementation ImageViewController

- (instancetype)initWithImage:(UIImage *)image {
  if (!(self = [super init])) { return nil; }
  
  self.imageView = [[UIImageView alloc] initWithImage:image];
  
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [self.view addSubview:self.imageView];
  
  UIGestureRecognizer *tap = [[UIGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
  [self.view addGestureRecognizer:tap];

  self.imageView.contentMode = UIViewContentModeScaleAspectFill;
}

- (void)tapped;
{
  NSLog(@"tapped!");
}

- (void)viewWillLayoutSubviews
{
  self.imageView.frame = self.view.bounds;
}

@end
