//
//  PhotoCollectionViewCell.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/2/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import "PhotoModel.h"

@interface PhotoCollectionViewCell : UICollectionViewCell

- (void)updateCellWithPhotoObject:(PhotoModel *)photo;

@end
