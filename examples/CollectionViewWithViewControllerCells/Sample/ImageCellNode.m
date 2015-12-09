//
//  ImageCellNode.m
//  Sample
//
//  Created by McCallum, Levi on 11/22/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "ImageCellNode.h"
#import "ImageViewController.h"

@implementation ImageCellNode {
  ASImageNode *_imageNode;
}

//- (id)initWithImage:(UIImage *)image
//{
//  self = [super init];
//  if (self != nil) {
//    _imageNode = [[ASImageNode alloc] init];
//    _imageNode.image = image;
//    [self addSubnode:_imageNode];
//  }
//  return self;
//}

- (id)initWithImage:(UIImage *)image
{
  return [self initWithViewControllerBlock:^UIViewController *{
    return [[ImageViewController alloc] initWithImage:image];
  }];
}

- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  [_imageNode measure:constrainedSize];
  return constrainedSize;
}

- (void)layout
{
  _imageNode.frame = CGRectMake(0, 0, _imageNode.calculatedSize.width, _imageNode.calculatedSize.height);
}

@end
