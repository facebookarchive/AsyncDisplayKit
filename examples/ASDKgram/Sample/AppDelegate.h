//
//  AppDelegate.h
//  ASDKgram
//
//  Created by Hannah Troisi on 2/16/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol PhotoFeedViewControllerProtocol <NSObject>
- (void)resetAllData;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIView   *statusBarOpaqueUnderlayView;

@end

