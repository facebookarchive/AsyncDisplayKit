//
//  ASWeakProxy.h
//  AsyncDisplayKit
//
//  Created by Garrett Moon on 4/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASWeakProxy : NSObject

@property (nonatomic, weak, readonly) id target;

+ (instancetype)weakProxyWithTarget:(id)target;

@end
