//
//  ASLayoutSpecDebuggingContext.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASLayoutElement.h"

NS_ASSUME_NONNULL_BEGIN

@interface ASLayoutSpecDebuggingContext : NSObject

// Intentionally atomic.
@property (nonatomic, strong) NSDictionary<NSString *, id> *overriddenProperties;

// Intentionally atomic.
@property (nonatomic, strong, readonly) id<ASLayoutElement> element;

@end

@interface ASLayoutSpecTree : NSObject

+ (nullable ASLayoutSpecTree *)currentTree;

+ (void)beginWithElement:(nullable id<ASLayoutElement>)element;

+ (void)end;

@property (nonatomic, strong, readonly, nullable) ASLayoutSpecDebuggingContext *context;
@property (nonatomic, strong, readonly) NSArray<ASLayoutSpecTree *> *subtrees;

- (ASLayoutSpecTree *)subtreeForElement:(id<ASLayoutElement>)element;

@end

NS_ASSUME_NONNULL_END
