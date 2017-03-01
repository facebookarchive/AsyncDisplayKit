//
//  ASCollectionLayoutHelpers.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 24/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASCollectionContentAttributes, ASLayout, ASElementMap;

extern AS_WARN_UNUSED_RESULT ASCollectionContentAttributes *ASLayoutToCollectionContentAttributes(ASLayout *layout, ASElementMap *elementMap);
