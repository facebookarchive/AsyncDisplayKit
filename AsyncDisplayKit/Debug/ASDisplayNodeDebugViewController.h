//
//  ASDisplayNodeDebugViewController.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface ASDisplayNodeDebugViewController : ASViewController

- (instancetype)initWithNodeForDebugging:(ASDisplayNode *)node sizes:(NSArray<NSValue *> *)sizes;

@end
