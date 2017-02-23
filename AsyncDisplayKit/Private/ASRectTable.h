//
//  ASRectTable.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/22/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

// Object -> CGRect
AS_SUBCLASSING_RESTRICTED
@interface ASRectTable<KeyType, id> : NSMapTable

+ (ASRectTable *)rectTableWithKeyOptions:(NSPointerFunctionsOptions)keyOptions;

- (CGRect)rectForKey:(KeyType)key;
- (void)setRect:(CGRect)rect forKey:(KeyType)key;

@end

// Int -> Object
AS_SUBCLASSING_RESTRICTED
@interface ASIntegerTable<id, ValueType> : NSMapTable
+ (ASRectTable *)integerTableWithValueOptions:(NSPointerFunctionsOptions)valueOptions;

- (nullable id)objectForInteger:(NSInteger)integer;
- (void)setObject:(nullable id)anObject forInteger:(NSInteger)integer;
@end

NS_ASSUME_NONNULL_END
