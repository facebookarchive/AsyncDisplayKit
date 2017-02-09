//
//  ASListTestObject.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 12/25/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <IGListKit/IGListKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASListTestObject : NSObject <IGListDiffable, NSCopying>

- (instancetype)initWithKey:(id <NSCopying>)key value:(id)value;

@property (nonatomic, strong, readonly) id key;
@property (nonatomic, strong) id value;

@end

NS_ASSUME_NONNULL_END
