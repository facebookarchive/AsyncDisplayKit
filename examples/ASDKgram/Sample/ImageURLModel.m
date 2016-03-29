//
//  ImageURLModel.m
//  ASDKgram
//
//  Created by Hannah Troisi on 3/11/16.
//  Copyright © 2016 Hannah Troisi. All rights reserved.
//

#import "ImageURLModel.h"

@implementation ImageURLModel

+ (NSString *)imageParameterForClosestImageSize:(CGSize)size
{
  BOOL squareImageRequested = (size.width == size.height) ? YES : NO;
  
  NSUInteger imageParameterID;
  
  if (squareImageRequested) {
    imageParameterID = [self imageParameterForSquareCroppedSize:size];
  }
  
  return [NSString stringWithFormat:@"&image_size=%lu", (long)imageParameterID];
}

// 500px standard cropped image sizes
+ (NSUInteger)imageParameterForSquareCroppedSize:(CGSize)size
{
  NSUInteger imageParameterID;
  
  if (size.height <= 70) {
    imageParameterID = 1;
  } else if (size.height <= 100) {
    imageParameterID = 100;
  } else if (size.height <= 140) {
    imageParameterID = 2;
  } else if (size.height <= 200) {
    imageParameterID = 200;
  } else if (size.height <= 280) {
    imageParameterID = 3;
  } else if (size.height <= 400) {
    imageParameterID = 400;
  } else {
    imageParameterID = 600;
  }
  
  return imageParameterID;
}

@end
