//
//  ASDebugOverlayElementDetailViewController.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@class ASLayoutSpecTree;

@interface ASDebugOverlayElementDetailViewController : ASViewController

- (instancetype)initWithTree:(ASLayoutSpecTree *)tree;

@end
