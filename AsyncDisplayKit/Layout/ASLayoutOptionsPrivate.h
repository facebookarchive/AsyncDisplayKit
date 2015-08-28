//
//  ASDisplayNode+Layoutable.h
//  AsyncDisplayKit
//
//  Created by Ricky Cancro on 8/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASDisplayNode.h>
#import <AsyncDisplayKit/ASLayoutSpec.h>


@interface ASDisplayNode()
{
  ASLayoutOptions *_layoutOptions;
}
@end

@interface ASDisplayNode(ASLayoutOptions)<ASLayoutable>
@end

@interface ASLayoutSpec()
{
  ASLayoutOptions *_layoutOptions;
}
@end

@interface ASLayoutSpec(ASLayoutOptions)<ASLayoutable>
@end

