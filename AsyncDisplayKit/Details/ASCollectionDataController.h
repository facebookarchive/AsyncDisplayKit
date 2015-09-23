//
//  ASCollectionDataController.h
//  Pods
//
//  Created by Levi McCallum on 9/22/15.
//
//

#import <AsyncDisplayKit/ASDataController.h>

@class ASDisplayNode, ASCollectionDataController;
@protocol ASDataControllerSource;

@protocol ASCollectionDataControllerSource <ASDataControllerSource>

- (ASDisplayNode *)dataController:(ASDataController *)dataController supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

- (NSArray *)supplementaryKindsInDataController:(ASCollectionDataController *)dataController;

@end

@interface ASCollectionDataController : ASDataController

- (ASDisplayNode *)supplementaryNodeOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;

@end