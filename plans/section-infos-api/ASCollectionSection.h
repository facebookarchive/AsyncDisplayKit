/**
 * Information about a section of items in a collection.
 *
 * This class is private to ASDK.
 * Data sources may override -collectionView:infoForSectionAtIndex: to provide the
 * "userInfo" object when the section is initially inserted. ASCollectionView
 * vends the user info object publicly via "infoForSectionAtIndex:".
*/
@interface ASCollectionSection : NSObject

// Autoincrementing value, set by collection view immediately after creation.
@property NSInteger sectionID;

@property NSMutableDictionary<NSString *, NSMutableArray<ASCellNode *> *> *editingNodesByKind;
@property NSMutableDictionary<NSString *, NSMutableArray<ASCellNode *> *> *completedNodesByKind;

@property (strong, nullable) id<ASSectionUserInfo> userInfo;

@end

@protocol ASSectionUserInfo
// This will be set once, immediately after the object is returned by the data source.
@property (weak, nonatomic, nullable) ASCollectionView *collectionView;

// Could be optional, but need to cache -respondsToSelector: dynamically.
@property (nullable, readonly, copy) NSString *sectionName;
@end
