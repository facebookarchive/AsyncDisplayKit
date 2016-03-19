//
//  ViewController.m
//  ASLayoutSpecPlayground
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ViewController.h"
#import "PlaygroundNode.h"

@interface ViewController ()

@end

// Need ASPagerNode, ASCollectionView, ASViewController or ASTableView to implement (calls measure: for you)

@implementation ViewController

#pragma mark - Lifecycle

- (instancetype)init
{
  
  self = [super initWithNode:[[PlaygroundNode alloc] init]];
  
  if (self) {
    
  }
  
  return self;
}

@end
