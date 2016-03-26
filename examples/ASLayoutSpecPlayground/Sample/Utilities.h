//
//  Utilities.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/9/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIColor (Additions)

+ (UIColor *)darkBlueColor;
+ (UIColor *)lightBlueColor;
+ (UIColor *)duskColor;
+ (UIColor *)customOrangeColor;

@end

@interface UIImage (Additions)

- (UIImage *)makeCircularImageWithSize:(CGSize)size;

@end

@interface NSAttributedString (Additions)

+ (NSAttributedString *)attributedStringWithString:(NSString *)string fontSize:(CGFloat)size
                                             color:(UIColor *)color firstWordColor:(UIColor *)firstWordColor;

@end