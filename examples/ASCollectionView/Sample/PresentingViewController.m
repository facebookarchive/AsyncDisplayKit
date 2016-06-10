//
//  PresentingViewController.m
//  AsyncDisplayKit
//
//  Created by Tom King on 12/23/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "PresentingViewController.h"
#import "ViewController.h"

@interface PresentingViewController ()

@end

@implementation PresentingViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Push Details" style:UIBarButtonItemStylePlain target:self action:@selector(pushNewViewController)];
}

- (void)pushNewViewController
{
  ViewController *controller = [[ViewController alloc] init];
  [self.navigationController pushViewController:controller animated:true];
}

@end
