//
//  VideoModel.h
//  Sample
//
//  Created by Erekle on 5/14/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VideoModel : NSObject
@property (nonatomic, strong, readonly) NSString* title;
@property (nonatomic, strong, readonly) NSURL *url;
@property (nonatomic, strong, readonly) NSString *userName;
@property (nonatomic, strong, readonly) NSURL *avatarUrl;
@end
