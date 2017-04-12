//
//  ASCollectionLayoutContext+Private.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 10/4/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCollectionLayoutContext.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASCollectionLayoutContext (Private)

- (instancetype)initWithViewportSize:(CGSize)viewportSize elements:(ASElementMap *)elements additionalInfo:(nullable id)additionalInfo;

@end

NS_ASSUME_NONNULL_END
