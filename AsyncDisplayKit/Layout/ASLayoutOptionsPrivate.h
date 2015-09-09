/*
 *  Copyright (c) 2014-present, Facebook, Inc.
 *  All rights reserved.
 *
 *  This source code is licensed under the BSD-style license found in the
 *  LICENSE file in the root directory of this source tree. An additional grant
 *  of patent rights can be found in the PATENTS file in the same directory.
 *
 */

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>


@interface ASDisplayNode()
{
  ASLayoutOptions *_layoutOptions;
  dispatch_once_t _layoutOptionsInitializeToken;
}
@end

@interface ASDisplayNode(ASLayoutOptions)<ASLayoutable>
@end

@interface ASLayoutSpec()
{
  ASLayoutOptions *_layoutOptions;
  dispatch_once_t _layoutOptionsInitializeToken;
}
@end

@interface ASLayoutSpec(ASLayoutOptions)<ASLayoutable>
@end

