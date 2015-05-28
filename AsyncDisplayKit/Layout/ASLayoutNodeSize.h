/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASDimension.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

/**
 A struct specifying a layout node's size. Example:
 
 ASLayoutNodeSize size = {
 .width = Percent(0.5),
 .maxWidth = 200,
 .minHeight = Percent(0.75)
 };
 
 // <ASLayoutNodeSize: exact={50%, Auto}, min={Auto, 75%}, max={200pt, Auto}>
 size.description();
 
 */
typedef struct {
  ASRelativeDimension width;
  ASRelativeDimension height;
  
  ASRelativeDimension minWidth;
  ASRelativeDimension minHeight;
  
  ASRelativeDimension maxWidth;
  ASRelativeDimension maxHeight;
} ASLayoutNodeSize;

extern ASLayoutNodeSize const ASLayoutNodeSizeZero;

ASDISPLAYNODE_EXTERN_C_BEGIN

extern ASLayoutNodeSize ASLayoutNodeSizeMakeWithCGSize(CGSize size);

extern ASLayoutNodeSize ASLayoutNodeSizeMake(CGFloat width, CGFloat height);

extern ASSizeRange ASLayoutNodeSizeResolve(ASLayoutNodeSize nodeSize, CGSize parentSize);

extern BOOL ASLayoutNodeSizeEqualToNodeSize(ASLayoutNodeSize lhs, ASLayoutNodeSize rhs);

extern NSString *NSStringFromASLayoutNodeSize(ASLayoutNodeSize nodeSize);

ASDISPLAYNODE_EXTERN_C_END
