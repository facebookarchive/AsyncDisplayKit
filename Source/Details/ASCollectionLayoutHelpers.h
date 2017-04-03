//
//  ASCollectionLayoutHelpers.h
//  AsyncDisplayKit
//
//  Created by Huy Nguyen on 24/3/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASBaseDefines.h>

@class ASCollectionLayoutState, ASLayout, ASElementMap;

extern AS_WARN_UNUSED_RESULT ASCollectionLayoutState *ASLayoutToCollectionContentAttributes(ASLayout *layout, ASElementMap *elementMap);
