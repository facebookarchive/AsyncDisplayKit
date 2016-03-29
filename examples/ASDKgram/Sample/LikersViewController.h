//
//  LikersViewController.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/14/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PhotoModel.h"

@interface LikersViewController : UIViewController

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithPhoto:(PhotoModel *)photo NS_DESIGNATED_INITIALIZER;

@end
