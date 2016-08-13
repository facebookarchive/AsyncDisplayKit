/**
 * Information about a section of items in a collection or table.
 *
 * Data sources may override -collectionView:infoForSectionAtIndex: to create and return
 * a subclass of this, and it can be retrieved by calling sectionInfoAtIndex:
*/
@interface ASCollectionSection : NSObject

// Autoincrementing value, set by collection view immediately after retrieval.
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
