//
//  ImageCellNode.m
//  Sample
//
//  Created by McCallum, Levi on 11/22/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ImageCellNode.h"

@implementation ImageCellNode {
  ASImageNode *_imageNode;
}

- (id)initWithImage:(UIImage *)image
{
  self = [super init];
  if (self != nil) {
    _imageNode = [[ASImageNode alloc] init];
    _imageNode.image = image;
    [self addSubnode:_imageNode];
  }
  return self;
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  [_imageNode measure:constrainedSize];
  return constrainedSize;
}

- (void)layout
{
  [super layout];
  
  _imageNode.frame = CGRectMake(0, 0, _imageNode.calculatedSize.width, _imageNode.calculatedSize.height);
}

@end
