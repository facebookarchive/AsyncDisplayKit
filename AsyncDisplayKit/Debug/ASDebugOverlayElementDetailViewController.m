//
//  ASDebugOverlayElementDetailViewController.m
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 1/7/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import "ASDebugOverlayElementDetailViewController.h"
#import "ASLayoutSpecDebuggingContext.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, ASDebugPropertyType) {
  ASDebugPropertyTypeEnum,
  ASDebugPropertyTypeFloat,
  ASDebugPropertyTypeDimension
};

@interface ASDebugProperty : NSObject
@property (nonatomic, strong) NSString *keyPath;
@property (nonatomic, strong) NSArray<NSString *> *enumValues;
@property (nonatomic) ASDebugPropertyType type;
@end

@implementation ASDebugProperty

- (NSString *)valueDescriptionWithObject:(id)object
{
  if (self.type == ASDebugPropertyTypeEnum) {
    NSInteger value = [[object valueForKeyPath:self.keyPath] integerValue];
    return self.enumValues[value];
  } else {
    // This won't handle Dimension types unfortunately
    return [[object valueForKeyPath:self.keyPath] description];
  }
}

@end

@interface ASDebugOverlayElementDetailViewController () <ASTableDelegate, ASTableDataSource>
@property (nonatomic, strong, readonly) ASLayoutSpecTree *tree;
@property (nonatomic, strong) ASTableNode *tableNode;
@end

@implementation ASDebugOverlayElementDetailViewController

+ (NSArray<ASDebugProperty *> *)supportedProperties
{
  static NSArray<ASDebugProperty *> *props;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableArray *m = [NSMutableArray array];
    ASDebugProperty *p = [[ASDebugProperty alloc] init];
    p.type = ASDebugPropertyTypeEnum;
    p.keyPath = @"justifyContent";
    p.enumValues = @[
                     @"ASStackLayoutJustifyContentStart",
                     @"ASStackLayoutJustifyContentCenter",
                     @"ASStackLayoutJustifyContentEnd",
                     @"ASStackLayoutJustifyContentSpaceBetween",
                     @"ASStackLayoutJustifyContentSpaceAround"
                     ];
    [m addObject:p];
    
    props = [m copy];
  });
  return props;
}

- (instancetype)initWithTree:(ASLayoutSpecTree *)tree
{
  
  ASTableNode *tableNode = [[ASTableNode alloc] initWithStyle:UITableViewStyleGrouped];
  if (self = [super initWithNode:tableNode]) {
    _tableNode = tableNode;
    tableNode.delegate = self;
    tableNode.dataSource = self;
    self.title = NSStringFromClass(tree.context.element.class);
    _tree = tree;
  }
  return self;
}

- (NSInteger)tableNode:(ASTableNode *)tableNode numberOfRowsInSection:(NSInteger)section
{
  return [[ASDebugOverlayElementDetailViewController supportedProperties] count];
}

- (ASCellNodeBlock)tableNode:(ASTableNode *)tableNode nodeBlockForRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDebugProperty *prop = [ASDebugOverlayElementDetailViewController supportedProperties][indexPath.item];
  id<ASLayoutElement> element = self.tree.context.element;
  NSString *valueString = nil;
  if ([element isKindOfClass:[ASStackLayoutSpec class]]) {
    valueString = [prop valueDescriptionWithObject:element];
  }
  return ^{
    ASTextCellNode *node = [[ASTextCellNode alloc] init];
    node.text = [NSString stringWithFormat:@"%@: %@", prop.keyPath, valueString];
    return node;
  };
}

- (void)tableNode:(ASTableNode *)tableNode didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  ASDebugProperty *prop = [ASDebugOverlayElementDetailViewController supportedProperties][indexPath.item];
  if (prop.type == ASDebugPropertyTypeEnum) {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [prop.enumValues enumerateObjectsUsingBlock:^(NSString * _Nonnull valueString, NSUInteger idx, BOOL * _Nonnull stop) {
      [ac addAction:[UIAlertAction actionWithTitle:valueString style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSMutableDictionary *d = [self.tree.context.overriddenProperties mutableCopy];
        d[prop.keyPath] = @(idx);
        self.tree.context.overriddenProperties = d;
        [self.tableNode reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
      }]];
    }];
    [ac addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
  }
}

     
@end
