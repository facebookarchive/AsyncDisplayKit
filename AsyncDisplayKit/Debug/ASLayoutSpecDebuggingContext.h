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

@property (nonatomic, strong) NSDictionary<NSString *, id> *overriddenProperties;

@property (nonatomic, strong, readonly) id<ASLayoutElement> element;

// The properties of the element, as the user set them.
@property (nonatomic, strong, readonly) NSDictionary *defaultProperties;

@end

@interface ASLayoutSpecTree : NSObject

+ (nullable ASLayoutSpecTree *)currentTree;

+ (void)beginWithElement:(nullable id<ASLayoutElement>)element;

+ (void)end;

@property (nonatomic, strong, readonly, nullable) ASLayoutSpecDebuggingContext *context;
@property (nonatomic, strong, readonly) NSArray<ASLayoutSpecTree *> *subtrees;

@property (nonatomic, readonly) NSInteger totalCount;

- (NSIndexPath *)indexPathForIndex:(NSInteger)index;

- (ASLayoutSpecTree *)subtreeAtIndexPath:(NSIndexPath *)indexPath;

- (ASLayoutSpecTree *)subtreeForElement:(id<ASLayoutElement>)element;

@end

NS_ASSUME_NONNULL_END
