//
//  ASRectTable.h
//  AsyncDisplayKit
//
//  Created by Adlai Holler on 2/24/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <AsyncDisplayKit/ASBaseDefines.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An alias for an NSMapTable created to store rects.
 *
 * You should not call -objectForKey:, -setObject:forKey:, or -allObjects
 * on these objects.
 */
typedef NSMapTable ASRectTable;

/**
 * A category for creating & using map tables meant for storing CGRects.
 *
 * This category is private, so name collisions are not worth worrying about.
 */
@interface NSMapTable<KeyType, id> (ASRectTableMethods)

/**
 * Creates a new rect table with (NSMapTableStrongMemory | NSMapTableObjectPointerPersonality) for keys.
 */
+ (ASRectTable *)rectTableForStrongObjectPointers;

/**
 * Creates a new rect table with (NSMapTableWeakMemory | NSMapTableObjectPointerPersonality) for keys.
 */
+ (ASRectTable *)rectTableForWeakObjectPointers;

/**
 * Retrieves the rect for a given key, or CGRectNull if the key is not found.
 *
 * @param key An object to lookup the rect for.
 */
- (CGRect)rectForKey:(KeyType)key;

/**
 * Sets the given rect for the associated key.
 *
 * @param rect The rect to store as value.
 * @param key The key to use for the rect.
 */
- (void)setRect:(CGRect)rect forKey:(KeyType)key;

/**
 * Removes the rect for the given key, if one exists.
 *
 * @param key The key to remove.
 */
- (void)removeRectForKey:(KeyType)key;

@end

NS_ASSUME_NONNULL_END
