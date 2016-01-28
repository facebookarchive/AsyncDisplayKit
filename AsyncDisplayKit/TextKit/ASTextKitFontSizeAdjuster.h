//
//  ASTextKitFontSizeAdjuster.h
//  AsyncDisplayKit
//
//  Created by Luke on 1/20/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASTextKitFontSizeAdjuster : NSObject

@property (nonatomic, assign) CGSize constrainedSize;

- (instancetype)initWithContext:(ASTextKitContext *)context
             minimumScaleFactor:(CGFloat)minimumScaleFactor
                constrainedSize:(CGSize)constrainedSize;

- (void) adjustFontSize;
@end
