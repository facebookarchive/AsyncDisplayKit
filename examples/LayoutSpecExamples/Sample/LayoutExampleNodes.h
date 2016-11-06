//
//  LayoutExampleNodes.h
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

@interface LayoutExampleNode : ASDisplayNode
+ (NSString *)title;
+ (NSString *)descriptionTitle;
@end

@interface HeaderWithRightAndLeftItems : LayoutExampleNode
@end

@interface PhotoWithInsetTextOverlay : LayoutExampleNode
@end

@interface PhotoWithOutsetIconOverlay : LayoutExampleNode
@end

@interface FlexibleSeparatorSurroundingContent : LayoutExampleNode
@end
