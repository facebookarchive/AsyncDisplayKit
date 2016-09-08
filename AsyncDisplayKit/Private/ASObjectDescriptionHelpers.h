//
//  ASObjectDescriptions.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 9/7/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AsyncDisplayKit/ASBaseDefines.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Your base class should conform to this and override `-debugDescription`
 * to call `[self propertiesForDebugDescription]` and use `ASObjectDescriptionMake`
 * to return a string. Subclasses of this base class just need to override
 * `propertiesForDebugDescription`, call super, and modify the result as needed.
 */
@protocol ASDebugDescriptionProvider
@required
- (NSMutableArray<NSDictionary *> *)propertiesForDebugDescription;
@end

/**
 * Your base class should conform to this and override `-description`
 * to call `[self propertiesForDescription]` and use `ASObjectDescriptionMake`
 * to return a string. Subclasses of this base class just need to override
 * `propertiesForDescription`, call super, and modify the result as needed.
 */
@protocol ASDescriptionProvider
@required
- (NSMutableArray<NSDictionary *> *)propertiesForDescription;
@end

ASDISPLAYNODE_EXTERN_C_BEGIN

/// Returns e.g. <MYObject: 0xFFFFFFFF; name = "Object Name"; frame = (0 0; 50 50)>
NSString *ASObjectDescriptionMake(id object, NSArray<NSDictionary *> * _Nullable propertyGroups);

/// Returns e.g. <MYObject: 0xFFFFFFFF>
NSString *ASObjectDescriptionMakeTiny(id object);

NSString * _Nullable ASStringWithQuotesIfMultiword(NSString * _Nullable string);

ASDISPLAYNODE_EXTERN_C_END

NS_ASSUME_NONNULL_END
