/**
 * An example of what a section info class might look like.
 */
@interface ASExampleLayoutSectionInfo : NSObject <ASSectionUserInfo>

@property (nonatomic, weak, nullable) ASCollectionView *collectionView;
@property (nullable, copy) NSString *sectionName;

@property CGSize cellSpacing;
@property NSInteger numberOfColumns;
@property CGFloat columnWidth;
@property CGSize headerSize;
@property CGSize footerSize;
@property UIEdgeInsets headerInsets;
@property UIEdgeInsets footerInsets;
@property ASExampleLayoutBackgroundType backgroundType;
@property ASExampleLayoutRowAlignmentType rowAlignmentType;
@end

@implementation ASExampleLayoutSectionInfo

@end