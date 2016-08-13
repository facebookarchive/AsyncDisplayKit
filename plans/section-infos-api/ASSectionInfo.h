/**
 * Information about a section of items in a collection or table.
 *
 * Data sources may override -collectionView:infoForSectionAtIndex: to create and return
 * a subclass of this, and it can be retrieved by calling sectionInfoAtIndex:
*/
@interface ASSectionInfo : NSObject

@property (weak, nullable, readonly) ASCollectionView *collectionView;
@property (nullable) NSString *debugName;

/**
 * We could add -nodes, -numberOfItems etc here later. For now we should make
 * this object pretty opaque.
 */

@end

@interface ASSectionInfo (Private)
// Autoincrementing value, set by collection view immediately after retrieval.
@property NSInteger sectionID;

@property NSMutableDictionary<NSString *, NSMutableArray<ASCellNode *> *> *editingNodesByKind;
@property NSMutableDictionary<NSString *, NSMutableArray<ASCellNode *> *> *completedNodesByKind;
@end
