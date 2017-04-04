//
//  ASCollectionLayoutContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class ASElementMap;

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionLayoutContext : NSObject

@property (nonatomic, assign, readonly) CGSize viewportSize;
@property (nonatomic, weak, readonly) ASElementMap *elementMap;

- (instancetype)initWithViewportSize:(CGSize)viewportSize elementMap:(ASElementMap *)map NS_DESIGNATED_INITIALIZER;

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END
