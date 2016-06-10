//
//  GradientTableNode.h
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

/**
 * This ASCellNode contains an ASTableNode.  It intelligently interacts with a containing ASCollectionView,
 * to preload and clean up contents as the user scrolls around both vertically and horizontally — in a way that minimizes memory usage.
 */
@interface GradientTableNode : ASCellNode <ASTableViewDelegate, ASTableViewDataSource>

- (instancetype)initWithElementSize:(CGSize)size;

@property (nonatomic) NSInteger pageNumber;

@end
