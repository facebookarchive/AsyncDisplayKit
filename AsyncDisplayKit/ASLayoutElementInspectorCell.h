//
//  ASLayoutElementInspectorCell.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCellNode.h>

typedef NS_ENUM(NSInteger, ASLayoutElementPropertyType) {
  ASLayoutElementPropertyFlexGrow = 0,
  ASLayoutElementPropertyFlexShrink,
  ASLayoutElementPropertyAlignSelf,
  ASLayoutElementPropertyFlexBasis,
  ASLayoutElementPropertySpacingBefore,
  ASLayoutElementPropertySpacingAfter,
  ASLayoutElementPropertyAscender,
  ASLayoutElementPropertyDescender,
  ASLayoutElementPropertyCount
};

@interface ASLayoutElementInspectorCell : ASCellNode

- (instancetype)initWithProperty:(ASLayoutElementPropertyType)property layoutElementToEdit:(id<ASLayoutElement>)layoutable NS_DESIGNATED_INITIALIZER;

@end

