//
//  ASLayoutElement+Yoga.m
//  AsyncDisplayKit
//
//  Created by Michael Schneider on 2/13/17.
//  Copyright © 2017 Facebook. All rights reserved.
//

#import <AsyncDisplayKit/ASAvailability.h>

#if YOGA
#import <Yoga/Yoga.h>

#import <AsyncDisplayKit/ASLayout.h>
#import <AsyncDisplayKit/ASDimensionInternal.h>
#import "ASLayoutElement+Yoga.h"
#import "ASLayoutElement.h"

#import <map>
#import <atomic>

@implementation ASLayoutElementStyle {
  std::atomic<ASStackLayoutDirection> _direction;
  std::atomic<CGFloat> _spacing;
  std::atomic<ASStackLayoutJustifyContent> _justifyContent;
  std::atomic<ASStackLayoutAlignItems> _alignItems;
  std::atomic<YGPositionType> _positionType;
  std::atomic<ASEdgeInsets> _position;
  std::atomic<ASEdgeInsets> _margin;
  std::atomic<ASEdgeInsets> _padding;
  std::atomic<ASEdgeInsets> _border;
  std::atomic<CGFloat> _aspectRatio;
  std::atomic<YGWrap> _flexWrap;
}
@end

@implementation ASLayoutElementStyle (Yoga)

#pragma mark - Yoga Flexbox Properties

- (ASStackLayoutDirection)direction           { return _direction.load(); }
- (CGFloat)spacing                            { return _spacing.load(); }
- (ASStackLayoutJustifyContent)justifyContent { return _justifyContent.load(); }
- (ASStackLayoutAlignItems)alignItems         { return _alignItems.load(); }
- (YGPositionType)positionType                { return _positionType.load(); }
- (ASEdgeInsets)position                      { return _position.load(); }
- (ASEdgeInsets)margin                        { return _margin.load(); }
- (ASEdgeInsets)padding                       { return _padding.load(); }
- (ASEdgeInsets)border                        { return _border.load(); }
- (CGFloat)aspectRatio                        { return _aspectRatio.load(); }
- (YGWrap)flexWrap                            { return _flexWrap.load(); }

- (void)setDirection:(ASStackLayoutDirection)direction         { _direction.store(direction); }
- (void)setSpacing:(CGFloat)spacing                            { _spacing.store(spacing); }
- (void)setJustifyContent:(ASStackLayoutJustifyContent)justify { _justifyContent.store(justify); }
- (void)setAlignItems:(ASStackLayoutAlignItems)alignItems      { _alignItems.store(alignItems); }
- (void)setPositionType:(YGPositionType)positionType           { _positionType.store(positionType); }
- (void)setPosition:(ASEdgeInsets)position                     { _position.store(position); }
- (void)setMargin:(ASEdgeInsets)margin                         { _margin.store(margin); }
- (void)setPadding:(ASEdgeInsets)padding                       { _padding.store(padding); }
- (void)setBorder:(ASEdgeInsets)border                         { _border.store(border); }
- (void)setAspectRatio:(CGFloat)aspectRatio                    { _aspectRatio.store(aspectRatio); }
- (void)setFlexWrap:(YGWrap)flexWrap                           { _flexWrap.store(flexWrap); }

@end

#endif
