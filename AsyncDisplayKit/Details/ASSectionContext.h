//
//  ASSectionContext.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 28/08/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>

@class ASCollectionView;

@protocol ASSectionContext

/**
 * Custom name of this section, for debugging only.
 */
@property (nonatomic, copy, nullable) NSString *sectionName;
@property (nonatomic, weak, nullable) ASCollectionView *collectionView;

@end
