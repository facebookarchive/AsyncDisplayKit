//
//  ASLayoutablePrivate.h
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 8/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//
#import <Foundation/Foundation.h>

@class ASLayoutSpec;
@class ASLayoutOptions;

@protocol ASLayoutablePrivate <NSObject>
- (ASLayoutSpec *)finalLayoutable;
@property (nonatomic, strong, readonly) ASLayoutOptions *layoutOptions;
@end
