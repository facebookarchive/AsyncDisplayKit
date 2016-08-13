/**
 * An example of what a section info subclass might look like.
 */
@interface ASExampleLayoutSectionInfo : ASSectionInfo
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