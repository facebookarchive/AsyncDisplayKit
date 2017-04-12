//
//  ASLayerBackingTipProvider.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 4/12/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASTipProvider.h"
#import <AsyncDisplayKit/ASBaseDefines.h>

#if AS_ENABLE_TIPS

NS_ASSUME_NONNULL_BEGIN

AS_SUBCLASSING_RESTRICTED
@interface ASLayerBackingTipProvider : ASTipProvider

@end

NS_ASSUME_NONNULL_END

#endif // AS_ENABLE_TIPS
