//
//  PINOperationTypes.h
//  PINOperation
//
//  Created by Adlai Holler on 1/10/17.
//  Copyright © 2017 Pinterest. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PINOperationQueuePriority) {
    PINOperationQueuePriorityLow,
    PINOperationQueuePriorityDefault,
    PINOperationQueuePriorityHigh,
};
