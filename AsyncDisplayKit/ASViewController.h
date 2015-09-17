//
//  ASViewController.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 16/09/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASDisplayNode.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASViewController : UIViewController

@property (nonatomic, strong, readonly) ASDisplayNode *node;

- (instancetype)initWithNode:(ASDisplayNode *)node;

@end

NS_ASSUME_NONNULL_END