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

AS_SUBCLASSING_RESTRICTED
@interface ASRectTable<KeyType> : NSMapTable

+ (ASRectTable *)rectTableWithKeyOptions:(NSPointerFunctionsOptions)keyOptions;

- (CGRect)rectForKey:(KeyType)key;
- (void)setRect:(CGRect)rect forKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
