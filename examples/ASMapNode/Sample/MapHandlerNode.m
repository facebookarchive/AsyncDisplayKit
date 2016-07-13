//
//  MapHandlerNode.m
//  Sample
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  FACEBOOK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
//  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "MapHandlerNode.h"

#import <AsyncDisplayKit/ASDisplayNode+Subclasses.h>

#import <AsyncDisplayKit/ASMapNode.h>
#import <AsyncDisplayKit/ASButtonNode.h>
#import <AsyncDisplayKit/ASEditableTextNode.h>

#import <AsyncDisplayKit/ASStackLayoutSpec.h>
#import <AsyncDisplayKit/ASInsetLayoutSpec.h>

@interface MapHandlerNode () <ASEditableTextNodeDelegate, MKMapViewDelegate>

@property (nonatomic, strong) ASEditableTextNode * latEditableNode;
@property (nonatomic, strong) ASEditableTextNode * lonEditableNode;
@property (nonatomic, strong) ASEditableTextNode * deltaLatEditableNode;
@property (nonatomic, strong) ASEditableTextNode * deltaLonEditableNode;
@property (nonatomic, strong) ASButtonNode * updateRegionButton;
@property (nonatomic, strong) ASButtonNode * liveMapToggleButton;
@property (nonatomic, strong) ASMapNode * mapNode;

@end

@implementation MapHandlerNode

#pragma mark - Lifecycle

- (instancetype)init
{
  if (!(self = [super init]))
    return nil;

  _latEditableNode      = [[ASEditableTextNode alloc] init];
  _lonEditableNode      = [[ASEditableTextNode alloc] init];
  _deltaLatEditableNode = [[ASEditableTextNode alloc] init];
  _deltaLonEditableNode = [[ASEditableTextNode alloc] init];

  _updateRegionButton   = [[ASButtonNode alloc] init];
  _liveMapToggleButton  = [[ASButtonNode alloc] init];
  _mapNode              = [[ASMapNode alloc] init];

  [self addSubnode:_latEditableNode];
  [self addSubnode:_lonEditableNode];
  [self addSubnode:_deltaLatEditableNode];
  [self addSubnode:_deltaLonEditableNode];

  [self addSubnode:_updateRegionButton];
  [self addSubnode:_liveMapToggleButton];
  [self addSubnode:_mapNode];

  return self;
}

- (void)didLoad
{
  [super didLoad];

  _latEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", _mapNode.region.center.latitude]];
  _lonEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", _mapNode.region.center.longitude]];
  _deltaLatEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", _mapNode.region.span.latitudeDelta]];
  _deltaLonEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", _mapNode.region.span.longitudeDelta]];

  [self configureEditableNodes:_latEditableNode];
  [self configureEditableNodes:_lonEditableNode];
  [self configureEditableNodes:_deltaLatEditableNode];
  [self configureEditableNodes:_deltaLonEditableNode];

  _mapNode.mapDelegate = self;

  [_updateRegionButton setTitle:@"Update Region" withFont:nil withColor:[UIColor blueColor] forState:ASControlStateNormal];
  [_updateRegionButton setTitle:@"Update Region" withFont:[UIFont systemFontOfSize:14] withColor:[UIColor blueColor] forState:ASControlStateHighlighted];
  [_updateRegionButton addTarget:self action:@selector(updateRegion) forControlEvents:ASControlNodeEventTouchUpInside];
  [_liveMapToggleButton setTitle:[self liveMapStr] withFont:nil withColor:[UIColor blueColor] forState:ASControlStateNormal];
  [_liveMapToggleButton setTitle:[self liveMapStr] withFont:[UIFont systemFontOfSize:14] withColor:[UIColor blueColor] forState:ASControlStateHighlighted];
  [_liveMapToggleButton addTarget:self action:@selector(toggleLiveMap) forControlEvents:ASControlNodeEventTouchUpInside];
}

#pragma mark - Layout

- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
#define SPACING 5
#define HEIGHT 30
  CGSize preferredSize = CGSizeMake(constrainedSize.max.width * 0.3, HEIGHT);

  _latEditableNode.preferredFrameSize = _lonEditableNode.preferredFrameSize = preferredSize;
  _deltaLatEditableNode.preferredFrameSize = _deltaLonEditableNode.preferredFrameSize = preferredSize;
  _updateRegionButton.preferredFrameSize = _liveMapToggleButton.preferredFrameSize = preferredSize;

  _latEditableNode.flexGrow = _lonEditableNode.flexGrow = true;
  _deltaLatEditableNode.flexGrow = _deltaLonEditableNode.flexGrow = true;
  _updateRegionButton.flexGrow = _liveMapToggleButton.flexGrow = true;

  _mapNode.flexGrow = true;

  ASStackLayoutSpec * lonlatSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                           spacing:SPACING
                                                                    justifyContent:ASStackLayoutJustifyContentStart
                                                                        alignItems:ASStackLayoutAlignItemsCenter
                                                                          children:@[_latEditableNode, _lonEditableNode]];
  lonlatSpec.flexGrow = true;

  ASStackLayoutSpec * deltaLonlatSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                                spacing:SPACING
                                                                         justifyContent:ASStackLayoutJustifyContentStart
                                                                             alignItems:ASStackLayoutAlignItemsCenter
                                                                               children:@[_deltaLatEditableNode, _deltaLonEditableNode]];
  deltaLonlatSpec.flexGrow = true;

  ASStackLayoutSpec * lonlatConfigSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                                 spacing:SPACING
                                                                          justifyContent:ASStackLayoutJustifyContentStart
                                                                              alignItems:ASStackLayoutAlignItemsStretch
                                                                                children:@[lonlatSpec, deltaLonlatSpec]];
  lonlatConfigSpec.flexGrow = true;

  ASStackLayoutSpec * buttonsSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                            spacing:SPACING
                                                                     justifyContent:ASStackLayoutJustifyContentStart
                                                                         alignItems:ASStackLayoutAlignItemsStretch
                                                                           children:@[_updateRegionButton, _liveMapToggleButton]];
  buttonsSpec.flexGrow = true;

  ASStackLayoutSpec * dashboardSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
                                                                              spacing:SPACING
                                                                       justifyContent:ASStackLayoutJustifyContentStart
                                                                           alignItems:ASStackLayoutAlignItemsStretch
                                                                             children:@[lonlatConfigSpec, buttonsSpec]];
  dashboardSpec.flexGrow = true;

  ASInsetLayoutSpec * insetSpec = [ASInsetLayoutSpec insetLayoutSpecWithInsets:UIEdgeInsetsMake(20, 10, 0, 10) child:dashboardSpec];

  ASStackLayoutSpec * layoutSpec = [ASStackLayoutSpec stackLayoutSpecWithDirection:ASStackLayoutDirectionVertical
                                                                           spacing:SPACING
                                                                    justifyContent:ASStackLayoutJustifyContentStart
                                                                        alignItems:ASStackLayoutAlignItemsStretch
                                                                          children:@[insetSpec, _mapNode ]];
  return layoutSpec;
}

#pragma mark - Button actions

-(void)updateRegion
{
  NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
  f.numberStyle = NSNumberFormatterDecimalStyle;

  double const lat = [f numberFromString:_latEditableNode.attributedText.string].doubleValue;
  double const lon = [f numberFromString:_lonEditableNode.attributedText.string].doubleValue;
  double const deltaLat = [f numberFromString:_deltaLatEditableNode.attributedText.string].doubleValue;
  double const deltaLon = [f numberFromString:_deltaLonEditableNode.attributedText.string].doubleValue;

  MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(lat, lon),
                                                     MKCoordinateSpanMake(deltaLat, deltaLon));

  _mapNode.region = region;
}

-(void)toggleLiveMap
{
  _mapNode.liveMap = !_mapNode.liveMap;
  NSString * const liveMapStr = [self liveMapStr];
  [_liveMapToggleButton setTitle:liveMapStr withFont:nil withColor:[UIColor blueColor] forState:ASControlStateNormal];
  [_liveMapToggleButton setTitle:liveMapStr withFont:[UIFont systemFontOfSize:14] withColor:[UIColor blueColor] forState:ASControlStateHighlighted];
}

#pragma mark - Helpers

-(NSString *)liveMapStr
{
  return _mapNode.liveMap ? @"Live Map is ON" : @"Live Map is OFF";
}

-(void)configureEditableNodes:(ASEditableTextNode *)node
{
  node.returnKeyType = node == _deltaLonEditableNode ? UIReturnKeyDone : UIReturnKeyNext;
  node.delegate = self;
}

#pragma mark - ASEditableTextNodeDelegate

- (BOOL)editableTextNode:(ASEditableTextNode *)editableTextNode shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
  if([text isEqualToString:@"\n"]) {
    if(editableTextNode == _latEditableNode)
      [_lonEditableNode becomeFirstResponder];
    else if(editableTextNode == _lonEditableNode)
      [_deltaLatEditableNode becomeFirstResponder];
    else if(editableTextNode == _deltaLatEditableNode)
      [_deltaLonEditableNode becomeFirstResponder];
    else if(editableTextNode == _deltaLonEditableNode) {
      [_deltaLonEditableNode resignFirstResponder];
      [self updateRegion];
    }
    return NO;
  }

  NSMutableCharacterSet * s = [NSMutableCharacterSet characterSetWithCharactersInString:@".-"];
  [s formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
  [s invert];

  NSRange r = [text rangeOfCharacterFromSet:s];
  if(r.location != NSNotFound) {
    return NO;
  }

  if([editableTextNode.attributedText.string rangeOfString:@"."].location != NSNotFound &&
      [text rangeOfString:@"."].location != NSNotFound) {
    return NO;
  }

  if ([editableTextNode.attributedText.string rangeOfString:@"-"].location != NSNotFound &&
      [text rangeOfString:@"-"].location != NSNotFound &&
      range.location > 0) {
    return NO;
  }

  return YES;
}

#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
  _latEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", mapView.region.center.latitude]];
  _lonEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", mapView.region.center.longitude]];
  _deltaLatEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", mapView.region.span.latitudeDelta]];
  _deltaLonEditableNode.attributedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%f", mapView.region.span.longitudeDelta]];
}

@end
