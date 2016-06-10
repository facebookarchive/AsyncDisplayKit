//
//  PhotoCellNode.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 2/17/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <CoreLocation/CLLocation.h>
#import "PhotoModel.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "PhotoTableViewCell.h"   // PhotoTableViewCellProtocol


@interface PhotoCellNode : ASCellNode

- (instancetype)initWithPhotoObject:(PhotoModel *)photo;

@end
