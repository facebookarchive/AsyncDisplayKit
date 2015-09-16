//
//  ASViewController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

@interface ASViewController : UIViewController

@property (nonatomic, strong, readonly, nonnull) ASDisplayNode *node;

- (nullable instancetype)initWithNode:(nonnull ASDisplayNode *)node;

@end
