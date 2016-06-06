//
//  OverviewDetailViewController.h
//  AsyncDisplayKitOverview
//
//  Created by Michael Schneider on 4/15/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@class ASDisplayNode;

@interface OverviewDetailViewController : UIViewController
- (instancetype)initWithNode:(ASDisplayNode *)node;
@end
