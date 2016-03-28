//
//  ASLayoutableInspectorCell.h
//  AsyncDisplayKit
//
//  Created by Hannah Troisi on 3/27/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASCellNode.h>

typedef NS_ENUM(NSInteger, ASLayoutablePropertyType) {
  ASLayoutablePropertyFlexGrow = 0,
  ASLayoutablePropertyFlexShrink,
  ASLayoutablePropertyAlignSelf,
  ASLayoutablePropertySpacingBefore,
  ASLayoutablePropertySpacingAfter,
  ASLayoutablePropertyAscender,
  ASLayoutablePropertyDescender,
  ASLayoutablePropertyCount
};

@interface ASLayoutableInspectorCell : ASCellNode

- (instancetype)initWithProperty:(ASLayoutablePropertyType)property layoutableToEdit:(id<ASLayoutable>)layoutable NS_DESIGNATED_INITIALIZER;

@end
