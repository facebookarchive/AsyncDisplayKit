//
//  UserProfileViewController.h
//  Flickrgram
//
//  Created by Hannah Troisi on 2/24/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UserModel.h"

@interface UserProfileViewController : UIViewController

//- (instancetype)initWithMe NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithUser:(UserModel *)user NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;


@end
