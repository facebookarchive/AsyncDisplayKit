//
//  ASTranslationRange.h
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 4/4/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASTranslationRange : NSObject

/**
 * The starting point of the range
 */
@property (nonatomic, assign) NSUInteger location;

/**
 * Designated initializer
 */
- (instancetype)initWithLocation:(NSUInteger)location length:(NSUInteger)length;

/**
 * The length of the range
 */
- (NSUInteger)length;

/**
 * Inserts a new offset point in the range at the given index
 */
- (void)insertOffsetAtIndex:(NSUInteger)index;

/**
 * Removes an offset in the range at the given index
 */
- (void)removeOffsetAtIndex:(NSUInteger)index;

/**
 * Returns an index offset via the current intersections in the range
 */
- (NSUInteger)translatedIndex:(NSUInteger)index;

@end
