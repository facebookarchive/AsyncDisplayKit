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

@property (nonatomic, strong, readonly) ASDisplayNode *node;

//TODO Use nonnull annotation late on. Travis doesn't recognize it (yet).
- (instancetype)initWithNode:(ASDisplayNode *)node;

@end
