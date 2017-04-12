//
//  ASCollectionLayoutContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 21/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASElementMap;

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED

@interface ASCollectionLayoutContext : NSObject

@property (nonatomic, assign, readonly) CGSize viewportSize;
@property (nonatomic, strong, readonly) ASElementMap *elements;
@property (nonatomic, strong, readonly, nullable) id additionalInfo;

- (instancetype)init __unavailable;

@end

NS_ASSUME_NONNULL_END
