//
//  ImageCollectionViewCell.m
//  Sample
//
//  Created by Hannah Troisi on 1/28/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ImageCollectionViewCell.h"

@implementation ImageCollectionViewCell
{
  UILabel *_title;
  UILabel *_description;
}

- (id)initWithFrame:(CGRect)aRect
{
  self = [super initWithFrame:aRect];
  if (self) {
    _title = [[UILabel alloc] init];
    _title.text = @"UICollectionViewCell";
    [self.contentView addSubview:_title];
    
    _description = [[UILabel alloc] init];
    _description.text = @"description for cell";
    [self.contentView addSubview:_description];
    
    self.contentView.backgroundColor = [UIColor orangeColor];
  }
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  [_title sizeToFit];
  [_description sizeToFit];
  
  CGRect frame = _title.frame;
  frame.origin.y = _title.frame.size.height;
  _description.frame = frame;
}

@end
