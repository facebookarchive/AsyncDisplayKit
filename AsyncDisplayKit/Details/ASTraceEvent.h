//
//  ASTraceEvent.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/13/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASTraceEvent : NSObject

/**
 * This method is dealloc safe.
 */
- (instancetype)initWithObject:(id)object
                     backtrace:(NSArray<NSString *> *)backtrace
                        format:(NSString *)format
                     arguments:(va_list)arguments NS_FORMAT_FUNCTION(3,0);

@property (nonatomic, readonly) NSArray<NSString *> *backtrace;
@property (nonatomic, strong, readonly) NSString *message;
@property (nonatomic, readonly) NSTimeInterval timestamp;

@end
