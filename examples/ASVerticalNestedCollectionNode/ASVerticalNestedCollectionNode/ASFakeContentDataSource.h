//
//  ASFakeContentDataSource.h
//  ASVerticalCollecttionNode
//
//  Created by Kieran Lafferty on 12/21/15.
//  Copyright © 2015 Kieran Lafferty. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASCollectionNode.h>

@interface ASFakeContentDataSource : NSObject
<
ASCollectionViewDataSource,
ASCollectionViewDelegateFlowLayout
>
@end
