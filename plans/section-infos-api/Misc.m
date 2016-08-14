// Added to ASCollectionDataSource:

/**
 * Data sources can override this method to return custom info associated with a
 * section of the collection view. 
 *
 * These section info objects can be read by a UICollectionViewLayout subclass
 * and used to configure the layout for that section. @see ASSectionUserInfo
 */
@optional
- (nullable id<ASSectionUserInfo>)collectionView:(ASCollectionView *)collectionView infoForSectionAtIndex:(NSInteger)sectionIndex;

// ----
// Added to ASCollectionView:

// Reads from data controller's _completedSections. Asserts that section index is in bounds.
- (nullable id<ASSectionUserInfo>)infoForSectionAtIndex:(NSInteger)sectionIndex;

// ----
// In ASDataController.mm:

// Replace _editingNodes and _completedNodes with:
NSMutableArray<ASCollectionSection *> *_editingSections;
NSMutableArray<ASCollectionSection *> *_completedSections;

// Modify _reloadDataWithAnimationOptions and insertSections:withAnimationOptions:.
// In those methods we use _populateFromDataSourceWithSectionIndexSet to get the node blocks.
// Now we will also need to create the ASCollectionSections and ask for UserInfos, just before we get the node blocks.

// In essence, wherever we use an NSMutableArray of nodes to represent a section, we now
// will use an ASCollectionSection instead.
