//
//  ASPagerFlowLayout.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/12/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ASPagerNode;

@protocol ASPagerFlowLayoutPageProvider <NSObject>

/// Provides the current page index to the ASPagerFlowLayout
- (NSInteger)currentPageIndex;

@end

@interface ASPagerFlowLayout : UICollectionViewFlowLayout

- (instancetype)initWithPageProvider:(id<ASPagerFlowLayoutPageProvider>)pageProvider;

@end
