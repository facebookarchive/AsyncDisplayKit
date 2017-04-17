//
//  ASDemoDataSource.h
//  
//
//  Created by Kieran Lafferty on 12/21/15.
//
//

#import <Foundation/Foundation.h>

#import <AsyncDisplayKit/ASCollectionNode.h>

@interface ASDemoDataSource : NSObject
<
ASCollectionViewDataSource,
ASCollectionViewDelegateFlowLayout
>

- (nonnull instancetype)initWithCollectionNodes:(nonnull NSArray<ASCollectionNode *> *)collectionNodes;

@end
