//
//  ImageCellNode.m
//  AsyncDisplayKit
//
//  Created by McCallum, Levi on 11/22/15.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
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
