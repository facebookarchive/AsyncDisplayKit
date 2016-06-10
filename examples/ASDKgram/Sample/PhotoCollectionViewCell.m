//
//  PhotoCollectionViewCell.m
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/2/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "PhotoCollectionViewCell.h"
#import "PINImageView+PINRemoteImage.h"
#import "PINButton+PINRemoteImage.h"

@implementation PhotoCollectionViewCell
{
  UIImageView  *_photoImageView;
}

#pragma mark - Lifecycle

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  
  if (self) {
  
    _photoImageView = [[UIImageView alloc] init];
    [_photoImageView setPin_updateWithProgress:YES];
    [self.contentView addSubview:_photoImageView];
  }
  
  return self;
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  
  _photoImageView.frame = self.bounds;
}

- (void)prepareForReuse
{
  [super prepareForReuse];
  
  // remove images so that the old content doesn't appear before the new content is loaded
  _photoImageView.image = nil;
}

#pragma mark - Instance Methods

- (void)updateCellWithPhotoObject:(PhotoModel *)photo
{
  // async download of photo using PINRemoteImage
  [_photoImageView pin_setImageFromURL:photo.URL];
}

@end
