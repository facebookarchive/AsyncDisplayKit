//
//  ImageURLModel.h
//  Flickrgram
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ImageURLModel : NSObject

+ (NSString *)imageParameterForClosestImageSize:(CGSize)size;

@end
