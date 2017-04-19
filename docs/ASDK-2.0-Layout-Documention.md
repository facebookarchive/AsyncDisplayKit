# ASDK 2.0 Layout
AsyncDisplayKit's automatic layout system is pretty powerful and loosely based on the CSS Box Model that a lot of developer are familiar from the web. Furthermore it provides components, so called layout specs, to layout and compose elements, called layoutables, in vastly different ways like in a flexbox or absolute fashion.

## Table of Contents
* [Differences from web](#differences-from-web)
  * [Naming properties](#naming-properties)
  * [No margin / padding properties](#no-margin--padding-properties)
  * [Missing features](#missing-features)
* [Layoutables](#layoutables)
  * [Replaced Layoutables](#replaced-layoutables)
* [Height and Width](#height-and-width)
  * [The content area](#the-content-area)
  * [Setting a size](#setting-a-size)
  * [Sizing Dimensions](#sizing-dimensions)
  * [Layout with Flexbox](#layout-with-flexbox)
  * [Absolute Layout](#absolute-layout)
* [Layout Properties](#layout-properties)
  * [The ASLayoutable protocol](#the-aslayoutable-protocol)
    * [@property (nonatomic, assign, readwrite) ASDimension width;](#property-nonatomic-assign-readwrite-asdimension-width)
    * [@property (nonatomic, assign, readwrite) ASDimension height;](#property-nonatomic-assign-readwrite-asdimension-height)
    * [@property (nonatomic, assign, readwrite) ASDimension minHeight;](#property-nonatomic-assign-readwrite-asdimension-minheight)
    * [@property (nonatomic, assign, readwrite) ASDimension maxHeight;](#property-nonatomic-assign-readwrite-asdimension-maxheight)
    * [@property (nonatomic, assign, readwrite) ASDimension minWidth;](#property-nonatomic-assign-readwrite-asdimension-minwidth)
    * [@property (nonatomic, assign, readwrite) ASDimension maxWidth;](#property-nonatomic-assign-readwrite-asdimension-maxwidth)
  * [The ASStackLayoutSpec protocol](#the-asstacklayoutspec-protocol)
    * [@property (nonatomic, assign) ASStackLayoutDirection direction;](#property-nonatomic-assign-asstacklayoutdirection-direction)
    * [@property (nonatomic, assign) CGFloat spacing;](#property-nonatomic-assign-cgfloat-spacing)
    * [@property (nonatomic, assign) ASHorizontalAlignment horizontalAlignment;](#property-nonatomic-assign-ashorizontalalignment-horizontalalignment)
    * [@property (nonatomic, assign) ASVerticalAlignment verticalAlignment;](#property-nonatomic-assign-asverticalalignment-verticalalignment)
    * [@property (nonatomic, assign) ASStackLayoutJustifyContent justifyContent;](#property-nonatomic-assign-asstacklayoutjustifycontent-justifycontent)
    * [@property (nonatomic, assign) ASStackLayoutAlignItems alignItems;](#property-nonatomic-assign-asstacklayoutalignitems-alignitems)
    * [@property (nonatomic, assign) BOOL baselineRelativeArrangement;](#property-nonatomic-assign-bool-baselinerelativearrangement)
  * [The ASStackLayoutable protocol](#the-asstacklayoutable-protocol)
    * [@property (nonatomic, readwrite) CGFloat spacingBefore;](#property-nonatomic-readwrite-cgfloat-spacingbefore)
    * [@property (nonatomic, readwrite) CGFloat spacingAfter;](#property-nonatomic-readwrite-cgfloat-spacingafter)
    * [@property (nonatomic, readwrite) BOOL flexGrow;](#property-nonatomic-readwrite-bool-flexgrow)
    * [@property (nonatomic, readwrite) BOOL flexShrink;](#property-nonatomic-readwrite-bool-flexshrink)
    * [@property (nonatomic, readwrite) ASDimension flexBasis;](#property-nonatomic-readwrite-asdimension-flexbasis)
    * [@property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;](#property-nonatomic-readwrite-asstacklayoutalignself-alignself)
    * [@property (nonatomic, readwrite) CGFloat ascender;](#property-nonatomic-readwrite-cgfloat-ascender)
    * [@property (nonatomic, readwrite) CGFloat descender;](#property-nonatomic-readwrite-cgfloat-descender)
  * [The ASStaticLayoutable protocol](#the-asstaticlayoutable-protocol)
    * [@property (nonatomic, assign) CGPoint layoutPosition;](#property-nonatomic-assign-cgpoint-layoutposition)
* [Layout Specs](#layout-specs)
* [Implementing layoutSpecThatFits:](#implementing-layoutspecthatfits)
* [Types of layout specs](#types-of-layout-specs)
  * [ASLayoutSpec](#aslayoutspec)
  * [ASWrapperLayoutSpec](#aswrapperlayoutspec)
  * [ASInsetLayoutSpec](#asinsetlayoutspec)
  * [ASOverlayLayoutSpec](#asoverlaylayoutspec)
  * [ASBackgroundLayoutSpec](#asbackgroundlayoutspec)
  * [ASCenterLayoutSpec](#ascenterlayoutspec)
  * [ASRatioLayoutSpec](#asratiolayoutspec)
  * [ASRelativeLayoutSpec](#asrelativelayoutspec)
  * [ASStackLayoutSpec: Flexbox Container](#asstacklayoutspec-flexbox-container)
  * [ASStaticLayoutSpec: Absolute Container](#asstaticlayoutspec-absolute-container)
* [Important methods](#important-methods)
  * [-[ASLayoutable layoutThatFits:]](#-aslayoutable-layoutthatfits)
  * [-[ASLayoutable calculateLayoutThatFits:]](#-aslayoutable-calculatelayoutthatfits)
  * [-[ASLayoutable calculateLayoutThatFits:restrictedToSize:relativeToParentSize:]](#-aslayoutable-calculatelayoutthatfitsrestrictedtosizerelativetoparentsize)
* [Determine the best size for a layoutable](#determine-the-best-size-for-a-layoutable)
* [Manual Layout](#manual-layout)
  * [Manual Layout UIKit](#manual-layout-uikit)
  * [Manual Layout ASDK](#manual-layout-asdk)
    * [calculateSizeThatFits and <code>layout</code>](#calculatesizethatfits-and-layout)
    * [Example](#example)
* [Ressources:](#ressources)

## Introduction
// TODO: Small introduction with an example

## Differences from web
The goal of AsyncDisplayKit's layout system is not to re-implement all of css. It only targets a subset of css and flexbox kind container, and does not have any plans on implementing support for tables, floats, or any other css concepts. The layout system itself also does not plan on supporting styling properties which do not affect layout such as color or background properties.

The layout system tries to stay as close as possible to css. There are however certain cases where it differs from the web:

### Naming properties
Certain properties have a different naming as on the web. For example `min-height` equivalent is the `minHeight` property. The full list of properties that control layout is documented in the `Layout Properties` section.

### No margin / padding properties
Layoutables don't have a padding or margin property. Instead wrapping a layoutable within a `ASInsetLayoutSpec` to apply padding or margin to the layoutable is the recommended way. See `ASInsetLayout` section for more information.

### Missing features
Certain features like `flexWrap` on a `ASStackLayoutSpec` are not supported currently. Please see the section for `Layout Properties` for the full list of properties that are supported.


## Layoutables
To understand AsyncDisplayKit's layout system it's crucial to understand what a layoutable and a layout spec is. Layoutables are classes that conform to the `ASLayoutable` protocol. The `ASLayoutable` protocol declares a methods for measuring the layout of an object. A layout is defined by an `ASLayout` return value, and must specify
  1. the size (but not position) of the layoutable object and
  2. the size and position of all of its immediate child objects.

`ASDisplayNode` as well as `ASLayoutSpec` classes are conforming to the `ASLayoutable` protocol and provide this functionally out of the box. This allows you to compose nodes and layout specs to build very complex layouts in a declarative way.

### Replaced Layoutables
A replaced layoutable is any layoutable whose appearance and dimensions are defined by an external resource. Examples include `ASImageNode`, `ASTextNode`, `ASButtonNode` or `ASTextNode`. All other layoutables can be referred to as non-replaced layoutables. This would include `ASVideoNode`, `ASVideoPlayerNode`, `ASNetworkImageNode` or `ASEditableTextNode`.

Replaced layoutables can have intrinsic dimensions—width and height values that are defined by the layoutable itself, rather than by its surroundings. For example, if an `ASImageNode` has a width set to `ASDimensionAuto`, the width of the linked image file will be used. For an `ASImageNode` the intrinsic content size would be calculated based on the text content.

## Height and Width

### The content area
The content area is the area containing the real content of a layoutable. The properties `width`, `minWidth`, `maxWidth`, `height`, `minHeight` and `maxHeight` control the content size.

### Setting a size
A layoutable's height and width dimensions determine its size on the screen. The simplest way to set the dimensions of a layoutable is by setting the fixed `width` and `height` property. All dimensions in AsyncDisplayKit's layout system are unitless, and represent density-independent pixels. Setting dimensions this way is common for layoutables that should always render at exactly the same size, regardless of screen dimensions.

```Obj-c
// Set a height of 0.5 points
layoutable.width = ASDimensionMake(ASDimensionTypePoints, 0.5);

// Set a width of 50%
layoutable.width = ASDimensionMake(ASDimensionTypePercentage, 0.5);
```

Besides width and height there is also `minWidth`, `minHeight`, `maxWidth` and `maxHeight` properties. For example an layoutable to which `minWidth` is applied will never be narrower than the minimum width specified, but it will be allowed to grow normally if its content exceeds the minimum width set. For a full description look at the `Layout Properties` section.

### Sizing Dimensions
Setting dimensions on layoutables are of the type `ASDimension`. `ASDimension` is essentially a normal CGFloat with support for representing either a point value, or a % value. It allows the same API to take in both fixed values, as well as relative ones:

```Obj-c
/**
 * A dimension relative to constraints to be provided in the future.
 * A RelativeDimension can be one of three types:
 *
 * "Auto" - This indicated "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances.
 *
 * "Points" - Just a number. It will always resolve to exactly this amount.
 *
 * "Percent" - Multiplied to a provided parent amount to resolve a final amount.
 */
typedef NS_ENUM(NSInteger, ASDimensionType) {
  /** This indicates "I have no opinion" and may be resolved in whatever way makes most sense given the circumstances. */
  ASDimensionTypeAuto,
  /** Just a number. It will always resolve to exactly this amount. This is the default type. */
  ASDimensionTypePoints,
  /** Multiplied to a provided parent amount to resolve a final amount. */
  ASDimensionTypeFraction,
};
```

When a relative percentage (%) value is used, it is resolved against the size of the parent. For example, an item with 50% flexBasis will ultimately have a point value set on it at the time that the stack achieves a concrete size.

As it can be pretty long to set the sizing dimensions via `ASDimension` create functions there are helper methods / functions for setting dimensions in an easier way:

```Obj-c
// ASDimensionMake is overloaded and can be used in multiple ways to declare dimensions e.g. for 50%
layoutable.height = ASDimensionMake(ASDimensionTypePercentage, 0.5); // Long form
layoutable.height = ASDimensionMake(@"0.5%");

// Use Helper macros to declare dimension e.g. for 100 points
layoutable.width = ASDimensionMake(ASDimensionTypePoints, 100); // Long form
layoutable.width = ASD(ASDimensionTypePoints, 100);
layoutable.width = ASDimensionMake(100);
layoutable.width = ASD(100);
layoutable.width = ASD(@"100pt");

// Use setter only properties e.g. for 100 points width and 200 points min height
layoutable.widthAsPoints = 100; // ASDimensionMake(ASDimensionTypePoints, 100);
layoutable.minHeightAsPoints = 200; // ASDimensionMake(ASDimensionTypePoints, 200);

// Use Helper category on NSNumber e.g. for 0.5
layoutable.width = @(100).as_points
layoutable.height = @(0.5).as_fraction
```

### Layout with Flexbox
An `ASStackLayoutSpec` is a layout spec that can specify the layout of its layoutable children using the flexbox algorithm. The children of a `ASStackLayoutSpec` needs to conform to the `ASStackLayoutable` protocol. It is based on a simplified version of [CSS flexbox](http://www.w3.org/TR/css-flexbox-1/). Flexbox is designed to provide a consistent layout on different screen sizes. You will normally use a combination of `-[ASStackLayoutSpec direction]`, `-[ASStackLayoutSpec alignItems]`, and `-[ASStackLayoutSpec justifyContent]` to achieve the right layout. See the `ASStackLayoutSpec` and `ASStackLayoutable` section for further details.

### Absolute Layout
An `ASStaticLayoutSpec` is a layout spec that can specify the layout of its layoutable children using absolute positioning. The children of a `ASStaticLayoutSpec` need to conform to the `ASStaticLayoutable` protocol. See the `ASStaticLayoutSpec` and `ASStaticLayoutable` section for further details.


## Layout Properties
List of properties that can be used to within the AsyncDisplayKit layout systems.

### The ASLayoutable protocol
Every class that conforms to the `ASLayoutable` protocol (currently this includes `ASDisplayNode` and `ASLayoutSpec`) has the following properties:

#### @property (nonatomic, assign, readwrite) ASDimension width;
This property sets the content width of a layoutable.

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the width of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content width automatically on the basis of other factors.

#### @property (nonatomic, assign, readwrite) ASDimension height;
This property sets the content height of a layoutable.

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the height of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content width automatically on the basis of other factors.

#### @property (nonatomic, assign, readwrite) ASDimension minHeight;
This property sets the minimum content height of a layoutable.

An layoutable to which `minHeight` is applied will never be narrower than the minimum height specified, but it will be allowed to grow normally if its content exceeds the minimum height set.

`minHeight` is often used in conjunction with `maxHeight` to produce a width range for the layoutable concerned.

Combining `minHeight` and `height`:
It should be noted that `minHeight` and `height` values should not be applied to the same layoutable if they use the same unit, as one will override the other. For example, if the height is set to 150 points and the `minHeight` is set to 60 points, the actual height of the layoutable is 150 points, and the `minHeight` declaration becomes redundant:

```Obj-c
layoutable.height = ASDimensionMake(150);
layoutable.minHeight = ASDimensionMake(60);
```

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the height of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content height automatically on the basis of other factors.

#### @property (nonatomic, assign, readwrite) ASDimension maxHeight;
This property sets the maximum content width of a layoutable.

A layoutable that has `maxHeight` applied will never be taller than the value specified, even if the height property is set to something larger. There is an exception to this rule, however: if `minHeight` is specified with a value that’s greater than that of `maxHeight`, the layoutable's height will be the largest value, which, in this case, means that the `minHeight` value will in fact be the one that’s applied.

`maxHeight` is usually used in conjunction with `minHeight` to produce a height range for the layoutable concerned.

Combining `maxHeight` and height
It should be noted that `maxHeight` and `height` should not be applied to the same layoutable using the same unit, as one will override the other. For example, if the height is set to 150px and the `maxHeight` set to 60px, the actual height of the layoutable is 60px, and the height declaration becomes redundant:

```Obj-c
layoutable.maxHeight = ASDimensionMake(60);
layoutable.height = ASDimensionMake(150);
```

In the above example, the height of the layoutable will be fixed at 60px.
In this example a `maxHeight` of 160px to a layoutable , and also assigns a height of 50%:

```Obj-c
layoutable.height = ASDimensionMakeWithFraction(0.5);  
layoutable.maxHeight = ASDimensionMake(160);
layoutable.height = ASDimensionAuto;
```

The height in the above example will be whichever is the smaller of the values.
Since the `maxHeight` declaration is based on fraction units, at some stage (due to text resizing) the fraction height may be smaller than the 138px height we’ve set. In cases such as these, the layoutable will be allowed to shrink from the 138px height, thus keeping track with the fraction-based text. See the entry on `minHeight` for the reverse of this scenario.

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the height of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content width automatically on the basis of other factors.

#### @property (nonatomic, assign, readwrite) ASDimension minWidth;
This property sets the minimum content width of a layoutable.

An layoutable to which `minWidth` is applied will never be narrower than the minimum width specified, but it will be allowed to grow normally if its content exceeds the minimum width set.

`minWidth` is often used in conjunction with `maxWidth` to produce a width range for the layoutable concerned.

Combining `minWidth` and `width`:
It should be noted that `minWidth` and `width` values should not be applied to the same layoutable if they use the same unit, as one will override the other. For example, if the width is set to 150 points and the `minWidth` is set to 60 points, the actual width of the layoutable is 150 points, and the `minWidth` declaration becomes redundant:

```Obj-c
layoutable.width = ASDimensionMake(150);
layoutable.minWidth = ASDimensionMake(60);
```

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the width of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content width automatically on the basis of other factors.

#### @property (nonatomic, assign, readwrite) ASDimension maxWidth;
This property sets the maximum content width of a layoutable.

A layoutable to which a `maxWidth` is applied will never be wider than the value specified even if the `width` property is set to be wider. There is an exception to this rule, however: if `minWidth` is specified with a value greater than that of `maxWidth`, the layoutable's `width` will be the largest value, which in this case means that the `minWidth` value will be the one that’s applied.

`maxWidth` is often used in conjunction with `minWidth` to produce a width range for the layoutable concerned.

Combining `maxWidth` and `width`
It should be noted that `maxWidth` and `width` shouldn’t be applied to the same layoutable using the same unit, as one will override the other. If, for example, the `width` is set to 150px and the `maxWidth` is set to 60px, the actual width of the layoutable will be 60px, and the width declaration will become redundant.

The following shows how conflicts are resolved where an layoutable has been given both a `width` and a `maxWidth` using the same unit (pixels in this case):

```Obj-c
layoutable.maxWidth = ASDimensionMake(60);
layoutable.width = ASDimensionMake(150);
```

In the above example, the width of the layoutable will be fixed at 60px.
In this example a `maxWidth` of 160px to a layoutable , and also assigns a width of 50%:

```Obj-c
layoutable.width = ASDimensionMakeWithFraction(0.5);  
layoutable.maxWidth = ASDimensionMake(160);
layoutable.height = ASDimensionAuto;
```

The final width of the layoutable in the above example will be the smallest value.
If you want an layoutable to scale when the container width is small, so that the layoutable doesn’t break out of its column, you could use the above example to ensure that the image’s size decreases once the available space is less than 160 pixels.
If the available space is greater than 160 pixels, the layoutable will expand until it’s 160 pixels wide—but no further. This ensures that the image stays at a sensible size—or its correct aspect ratio—when space allows.
The `minWidth` property can be used for the reverse of this scenario.

The property takes an `ASDimension` of types `ASDimensionTypePoints`, an `ASDimensionTypeFraction`, or the special `ASDimensionAuto`. Values of `ASDimension`s from type `ASDimensionTypeFraction` refer to the width of the layoutables containing layoutable. Negative length values are illegal.

The special `ASDimensionAuto` allows the layout system to calculate the content width automatically on the basis of other factors.


### The ASStackLayoutSpec protocol
`ASStackLayoutSpec` can be seen as a flex container that childrens act as flex items. Every child must conform to the `ASStackLayoutable` protocol though. See the `ASStackLayoutable` section for more information.

#### @property (nonatomic, assign) ASStackLayoutDirection direction;
Specifies the direction children are stacked in. If horizontalAlignment and verticalAlignment were set, they will be resolved again, causing justifyContent and alignItems to be updated accordingly. flexDirection controls which directions children of a container go. `ASStackLayoutDirectionVertical` goes left to right, `ASStackLayoutDirectionHorizontal` goes top to bottom. It works like flex-direction in CSS except `row-reverse` and `column-reverse` are not supported.  See https://css-tricks.com/almanac/properties/f/flex-direction/ for more detail.

#### @property (nonatomic, assign) CGFloat spacing;
The amount of space between each child.

#### @property (nonatomic, assign) ASHorizontalAlignment horizontalAlignment;
Specifies how children are aligned horizontally. Depends on the stack direction, setting the alignment causes either `justifyContent` or `alignItems` to be updated. The alignment will remain valid after future direction changes. Thus, it is preferred to those properties

#### @property (nonatomic, assign) ASVerticalAlignment verticalAlignment;
Specifies how children are aligned vertically. Depends on the stack direction, setting the alignment causes either `justifyContent` or `alignItems` to be updated. The alignment will remain valid after future direction changes. Thus, it is preferred to those properties

#### @property (nonatomic, assign) ASStackLayoutJustifyContent justifyContent;
If no children are flexible, how should this spec justify its children in the available space. `justifyContent` aligns children in the main direction. For example, if children are flowing vertically, `justifyContent` controls how they align vertically. It works like justify-content in CSS. See https://css-tricks.com/almanac/properties/j/justify-content/ for more detail.

#### @property (nonatomic, assign) ASStackLayoutAlignItems alignItems;
Orientation of children along cross axis. For example, if children are flowing vertically, alignItems controls how they align horizontally. It works like align-items in CSS. The default value is flex-start. See https://css-tricks.com/almanac/properties/a/align-items/ for more detail.

#### @property (nonatomic, assign) BOOL baselineRelativeArrangement;
If YES the vertical spacing between two views is measured from the last baseline of the top view to the top of the bottom view

### The ASStackLayoutable protocol
Every class that conforms to the `ASStackLayoutable` protocol (currently this includes `ASDisplayNode` and `ASLayoutSpec`) can be used as child in a `ASStackLayoutSpec`.

#### @property (nonatomic, readwrite) CGFloat spacingBefore;
Additional space to place before this object in the stacking direction.

#### @property (nonatomic, readwrite) CGFloat spacingAfter;
Additional space to place after this object in the stacking direction.

#### @property (nonatomic, readwrite) BOOL flexGrow;
If the sum of childrens' stack dimensions is less than the minimum size, should this object grow? Used when attached to a stack layout.

#### @property (nonatomic, readwrite) BOOL flexShrink;
f the sum of childrens' stack dimensions is greater than the maximum size, should this object shrink? Used when attached to a stack layout.

#### @property (nonatomic, readwrite) ASDimension flexBasis;
Specifies the initial size for this object, in the stack dimension (horizontal or vertical), before the flexGrow or flexShrink properties are applied and the remaining space is distributed.

#### @property (nonatomic, readwrite) ASStackLayoutAlignSelf alignSelf;
Orientation of the object along cross axis, overriding alignItems. Used when attached to a stack layout.

#### @property (nonatomic, readwrite) CGFloat ascender;
Used for baseline alignment. The distance from the top of the object to its baseline

#### @property (nonatomic, readwrite) CGFloat descender;
Used for baseline alignment. The distance from the baseline of the object to its bottom.

### The ASStaticLayoutable protocol
To layout layoutables absolute you can wrap them in a `ASStaticLayoutSpec`. All children of an `ASStaticLayoutSpec` needs to conform to the `ASStaticLayoutable` protocol.

#### @property (nonatomic, assign) CGPoint layoutPosition;
The position of this object within its parent layout spec.


## Layout Specs
AsyncDisplayKit includes a library of layout spec components that can be composed together with layoutables to declaratively specify a layout.
Child(ren) of a layout spec need to conform to the at least `ASLayoutable` protocol. `ASDisplayNode` and `ASLayoutSpec` both conform to the `ASLayoutable` protocol.

In the below image, an `ASStackLayoutSpec` (vertical) containing a `ASTextNode` and an `ASImageNode`, is wrapped in another `ASStackLayoutSpec` (horizontal) with another text node.

![Layoutable Types](http://asyncdisplaykit.org/static/images/layoutable-types.png)


## Implementing `layoutSpecThatFits:`
The composing of layout specs and layoutables are happening within the `layoutSpecThatFits:` method. This is where you will put the majority of your layout code. It defines the layout and does the heavy calculation on a background thread.

Every `ASDisplayNode` that would like to layout it's subnodes should should do this by implementing the `layoutSpecThatFits:` method. This method is where you build out a layout spec object that will produce the size of the node, as well as the size and position of all subnodes.

The following `layoutSpecThatFits:` implementation is from the Kittens example and will implement an easy stack layout with an image with a constrained size on the left and a text to the right. The great thing is, by using a `ASStackLayoutSpec` the height is dynamically calculated based on the image height and the height of the text.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // Set an intrinsic size for the image node
  CGSize imageSize = _isImageEnlarged ? CGSizeMake(2.0 * kImageSize, 2.0 * kImageSize)
                                      : CGSizeMake(kImageSize, kImageSize);
  [_imageNode setSizeFromCGSize:imageSize];

  // Shrink the text node in case the image + text gonna be too wide
  _textNode.flexShrink = YES;

  // Configure stack
  ASStackLayoutSpec *stackLayoutSpec =
  [ASStackLayoutSpec
   stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
   spacing:kInnerPadding
   justifyContent:ASStackLayoutJustifyContentStart
   alignItems:ASStackLayoutAlignItemsStart
   children:_swappedTextAndImage ? @[_textNode, _imageNode] : @[_imageNode, _textNode]];

  // Add inset
  return [ASInsetLayoutSpec
          insetLayoutSpecWithInsets:UIEdgeInsetsMake(kOuterPadding, kOuterPadding, kOuterPadding, kOuterPadding)
          child:stackLayoutSpec];
}
```

The result looks like the following:
![Kittens Node](https://d3vv6lp55qjaqc.cloudfront.net/items/2l133Y2B3r1F231a310q/Screen%20Shot%202016-08-23%20at%202.29.12%20PM.png)

Let's look at some more advanced composition of layout spec and layoutable implementation from the `ASDKGram` example that should give you a feel how layout specs and layoutables can be combined to compose a difficult layout. You can also find this code in the `examples/ASDKGram` folder.

```Swift
override func layoutSpecThatFits(constrainedSize: ASSizeRange) -> ASLayoutSpec {

  // ASImageNode layoutable - constrain avatar image frame size
  self.userAvatarImageView.width = ASDimensionMake(USER_IMAGE_HEIGHT);
  self.userAvatarImageView.height = ASDimensionMake(USER_IMAGE_HEIGHT);

  // ASLayoutSpec as spacer
  let spacer = ASLayoutSpec()
  spacer.flexGrow = true

  // header stack
  let headerStack = ASStackLayoutSpec.horizontalStackLayoutSpec()
  headerStack.alignItems = .Center;       // center items vertically in horizontal stack
  headerStack.justifyContent = .Start;    // justify content to left side of header stack
  headerStack.spacing = HORIZONTAL_BUFFER;
  headerStack.children = [self.userAvatarImageView, self.userNameLabel, spacer, self.photoTimeIntervalSincePostLabel]

  // header inset stack
  let insets = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  let headerWithInset = ASInsetLayoutSpec(insets: insets, child: headerStack)
  headerWithInset.flexShrink = true;

  // footer stack
  let footerStack = ASStackLayoutSpec.verticalStackLayoutSpec();
  footerStack.spacing = VERTICAL_BUFFER;
  footerStack.children = self.photoLikesLabel, self.photoDescriptionLabel, self.photoCommentsView

  // footer inset stack
  let footerInsets = UIEdgeInsetsMake(VERTICAL_BUFFER, HORIZONTAL_BUFFER, VERTICAL_BUFFER, HORIZONTAL_BUFFER);
  let footerWithInset = ASInsetLayoutSpec(insets: footerInsets, child: footerStack)

  // ASNetworkImageNode layoutable - constrain photo frame size
  let cellWidth = constrainedSize.max.width;
  self.photoImageView.size.width = ASDimensionMake(cellWidth);
  self.photoImageView.size.height = ASDimensionMake(cellWidth);

  // vertical stack
  let verticalStack   = ASStackLayoutSpec.verticalStackLayoutSpec();
  verticalStack.alignItems = .Stretch;    // stretch headerStack to fill horizontal space
  verticalStack.children = [headerWithInset, self.photoImageView, footerWithInset]
  return verticalStack;
}
```

After the layout pass happened the result will look like the following:
![ASDKGram](https://d3vv6lp55qjaqc.cloudfront.net/items/1l0t352p441K3k0C3y1l/layout-example-2.png)

The layout spec object that you create in `layoutSpecThatFits:` is mutable up until the point that it is return in this method. After this point, it will be immutable. It's important to remember not to cache layout specs for use later but instead to recreate them when necessary.

Note: Because it is run on a background thread, you should not set any node.view or node.layer properties here. Also, unless you know what you are doing, do not create any nodes in this method. Additionally, it is not necessary to begin this method with a call to super, unlike other method overrides.

## Types of layout specs
AsyncDisplayKit includes different types of layout specs that can be used to compose very complicated layouts. All of the layout spec children need to conform to the `ASLayoutable` protocol. Currently `ASDisplayNode` and `ASLayoutSpec` both conform to the `ASLayoutable` protocol.

### ASLayoutSpec
`ASLayoutSpec` is the main class from that all layout spec's are subclassed. It's main job is to handle all the children management, but it also can be used to create custom layout specs. There should be not really a lot of situations where you have to create a custom subclasses of `ASLayoutSpec` though. Instead try to use provided layout specs and compose them together to create more advanced layouts. For examples how to create custom layout spec's look into the already provided layout specs for more details.

Furthermore `ASLayoutSpec` objects can be used as a spacer in a `ASStackLayoutSpec` with other children, when `.flexGrow` and/or `.flexShrink` is applied.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  // ASLayoutSpec as spacer
  let spacer = ASLayoutSpec()
  spacer.flexGrow = true

  stack.children = [imageNode, spacer, textNode]
  ...
}
```

### ASWrapperLayoutSpec
ASWrapperLayoutSpec can be used to wrap another layoutable and passes the size calculation through.
This can be used if an `ASDisplayNode` should be returned in `layoutSpecThatFits:`. As you have to return a `ASLayoutSpec` from `layoutSpecThatFits:` you can wrap the `ASDisplayNode` in a `ASWrapperLayoutSpec` and return it.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // 100% of container
  _node.width = ASDimensionMakeWithFraction(1.0);
  _node.height = ASDimensionMakeWithFraction(1.0);
  return [ASWrapperLayoutSpec wrapperWithLayoutable:_node];
}
```

### ASInsetLayoutSpec
ASInsetLayoutSpec applies an inset margin around it's child layoutable. If you use INFINITY as one of the edge insets. The layoutable is being inset must have an instrinsic size or explicitly set a size to it.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ...
  // header inset stack
  let insets = UIEdgeInsetsMake(0, HORIZONTAL_BUFFER, 0, HORIZONTAL_BUFFER);
  let headerWithInset = ASInsetLayoutSpec(insets: insets, child: headerStack)
  ...
}
```

### ASOverlayLayoutSpec
Lays out a component, stretching another component on top of it as an overlay. The underlay layoutable must have an intrinsic size or explictly set a size to it.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor blackColor], {20, 20});

  return [ASOverlayLayoutSpec overlayLayoutSpecWithChild:backgroundNode overlay:foregroundNode]];
}
```

Note: A current limitation is that the order in which subnodes are added matters for this layout spec. The overlay layoutable must be added as a subnode to the parent node after the underlaying layoutable.

### ASBackgroundLayoutSpec
Lays out a component, stretching another component behind it as a backdrop. The foreground layoutable must have an intrinsic size.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor blueColor]);
  ASDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor blackColor], {20, 20});

  return [ASBackgroundLayoutSpec backgroundLayoutSpecWithChild:foregroundNode background:backgroundNode]];
}
```

Note: The order in which subnodes are added matters for this layout spec; the background object must be added as a subnode to the parent node before the foreground object.

### ASCenterLayoutSpec
Centers a component in the available space.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(70, 100));
  return [ASCenterLayoutSpec
          centerLayoutSpecWithCenteringOptions:ASCenterLayoutSpecCenteringXY
          sizingOptions:ASRelativeLayoutSpecSizingOptionDefault
          child:subnode]
}
```

Note: The ASCenterLayoutSpec must have an intrinsic size.

### ASRatioLayoutSpec
Lays out a component at a fixed aspect ratio (which can be scaled).

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  // Half Ratio
  ASStaticSizeDisplayNode *subnode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(100, 100));
  return [ASRatioLayoutSpec ratioLayoutSpecWithRatio:0.5 child:subnode];
}
```

Note: This spec is great for objects that do not have an intrinsic size, such as ASNetworkImageNodes and ASVideoNodes.

### ASRelativeLayoutSpec
Lays out a component and positions it within the layout bounds according to vertical and horizontal positional specifiers. Similar to the “9-part” image areas, a child can be positioned at any of the 4 corners, or the middle of any of the 4 edges, as well as the center.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASDisplayNode *backgroundNode = ASDisplayNodeWithBackgroundColor([UIColor redColor]);
  ASStaticSizeDisplayNode *foregroundNode = ASDisplayNodeWithBackgroundColor([UIColor greenColor], CGSizeMake(70, 100));

  ASLayoutSpec *layoutSpec =
  [ASBackgroundLayoutSpec
   backgroundLayoutSpecWithChild:
   [ASRelativeLayoutSpec
    relativePositionLayoutSpecWithHorizontalPosition:ASRelativeLayoutSpecPositionStart
    verticalPosition:ASRelativeLayoutSpecPositionStart
    sizingOption:ASRelativeLayoutSpecSizingOptionDefault
    child:foregroundNode]
   background:backgroundNode];

   return layoutSpec;
}
```

### ASStackLayoutSpec: Flexbox Container
Of all the layoutSpecs in ASDK,  ASStackLayoutSpec is probably the most useful and the most powerful. `ASStackLayoutSpec` can specify the layout of its children using the flexbox algorithm. Flexbox is designed to provide a consistent layout on different screen sizes. In a stack layout you align items in either a vertical or horizontal stack. A stack layout can be a child of another stack layout, which makes it possible to create almost any layout using a stack layout spec. You will normally use a combination of direction, alignItems, and justifyContent to achieve the right layout.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  ASStackLayoutSpec *mainStack =
  [ASStackLayoutSpec
   stackLayoutSpecWithDirection:ASStackLayoutDirectionHorizontal
   spacing:6.0
   justifyContent:ASStackLayoutJustifyContentStart
   alignItems:ASStackLayoutAlignItemsCenter
   children:@[_iconNode, _countNode]];

  // Set some constrained size to the stack
  mainStack.minWidth = ASDimensionMakeWithPoints(60.0);
  mainStack.maxHeight = ASDimensionMakeWithPoints(40.0);

  return mainStack;
}
```

Flexbox works the same way in AsyncDisplayKit as it does in CSS on the web, with a few exceptions. The defaults are different, there is no `flex` parameter and `flexGrow` and `flexShrink` only supports a boolean value.

### ASStaticLayoutSpec: Absolute Container
Within `ASStaticLayoutSpec` you can specify exact locations (x/y coordinates) of its layoutable children by setting the `layoutPosition` property. Absolute layouts are less flexible and harder to maintain than other types of layouts without absolute positioning.

```Obj-c
- (ASLayoutSpec *)layoutSpecThatFits:(ASSizeRange)constrainedSize
{
  CGSize maxConstrainedSize = constrainedSize.max;

  // Layout all nodes absolute in a static layout spec
  guitarVideoNode.layoutPosition = CGPointMake(0, 0);
  guitarVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width, maxConstrainedSize.height / 3.0));

  nicCageVideoNode.layoutPosition = CGPointMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0);
  nicCageVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0));

  simonVideoNode.layoutPosition = CGPointMake(0.0, maxConstrainedSize.height - (maxConstrainedSize.height / 3.0));
  simonVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width/2, maxConstrainedSize.height / 3.0));

  hlsVideoNode.layoutPosition = CGPointMake(0.0, maxConstrainedSize.height / 3.0);
  hlsVideoNode.size = ASSizeMakeFromCGSize(CGSizeMake(maxConstrainedSize.width / 2.0, maxConstrainedSize.height / 3.0));

  return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[guitarVideoNode, nicCageVideoNode, simonVideoNode, hlsVideoNode]];
}
```

## Important methods

### -[ASLayoutable layoutThatFits:]
Either returns a cached layout or creates a layout based on the given `ASSizeRange` that represents the size and position of the object that created it and returns it. Though this method does not set the bounds of the view, it does have side effects--caching both the constraint and the result size. Subclasses must not override this; it caches results from ``-[ASLayoutable calculateLayoutThatFits:]`.  Calling this method may be expensive if result is not cached.
```Obj-c
- [ASLayoutable layoutThatFits:] // and
- [ASLayoutable layoutThatFits:parentSize:]
```

### -[ASLayoutable calculateLayoutThatFits:]
If the provided layout specs aren’t powerful enough, you can implement `calculateLayoutThatFits:` manually. This method passes you a `ASSizeRange` that specifies a min size and a max size. Choose any size in the given range, then return a `ASLayout` structure with the layout of child components.

```Obj-c
- [ASLayoutable calculateLayoutThatFits:]
```

For sample implementations of `calculateLayoutThatFits:`, check out the layout specs in AsyncDisplayKit itself!

### -[ASLayoutable calculateLayoutThatFits:restrictedToSize:relativeToParentSize:]

`-[ASLayoutable layoutThatFits:parentSize:]` calls this method to resolve the component's size against parentSize, intersect it with constrainedSize, and call -calculateLayoutThatFits: with the result.
In certain advanced cases, you may want to customize this logic. Overriding this method allows you to receive all three parameters and do the computation yourself.
```Obj-c
- [ASLayoutable calculateLayoutThatFits:restrictedToSize:relativeToParentSize:]
```

## Determine the best size for a layoutable

To calculate the best size for a layoutable that can but not have to be constrained to a specific size range you should use the `layoutThatFits:` method. You pass in an `ASSizeRange` as parameter that has a min and max size and you get back an `ASLayout` on that you can call `size`:

```Obj-c
// Constrained width and height
ASLayout *layout = [node layoutThatFits:ASSizeRangeMake(CGSizeMake(300, 300))];
CGSize optimalSize = layout.size;
```

To let a display node return a layout without any constraints in one dimension (or both dimensions) you can pass in `INFINITY` or `CGFLOAT_MAX` as one of the dimensions in the size range you pass in as parameter.

```Obj-c
// Unconstrained in height, but a constrained width
CGSize optimalSize = [node layoutThatFits:ASSizeRangeMake({CGFLOAT_MAX, 360})].size;

// Unconstrained in height and width
CGSize optimalSize = [node layoutThatFits:ASSizeRangeMake({CGFLOAT_MAX, CGFOAT_MAX})].size;
```

## Manual Layout
After diving in to the automatic way for layout in ASDK there is still the _old_ way to layout manually available. For the sake of completness here is a short description how to accomplish that within ASDK.

### Manual Layout UIKit

Sizing and layout of custom view hierarchies are typically done all at once on the main thread.  For example, a custom UIView that minimally encloses a text view and an image view might look like this:

```Obj-c
- (CGSize)sizeThatFits:(CGSize)size
{
  // size the image
  CGSize imageSize = [_imageView sizeThatFits:size];

  // size the text view
  CGSize maxTextSize = CGSizeMake(size.width - imageSize.width, size.height);
  CGSize textSize = [_textView sizeThatFits:maxTextSize];

  // make sure everything fits
  CGFloat minHeight = MAX(imageSize.height, textSize.height);
  return CGSizeMake(size.width, minHeight);
}

- (void)layoutSubviews
{
  CGSize size = self.bounds.size; // convenience

  // size and layout the image
  CGSize imageSize = [_imageView sizeThatFits:size];
  _imageView.frame = CGRectMake(size.width - imageSize.width, 0.0f,
                                imageSize.width, imageSize.height);

  // size and layout the text view
  CGSize maxTextSize = CGSizeMake(size.width - imageSize.width, size.height);
  CGSize textSize = [_textView sizeThatFits:maxTextSize];
  _textView.frame = (CGRect){ CGPointZero, textSize };
}
```

This isn't ideal.  We're sizing our subviews twice &mdash; once to figure out how big our view needs to be and once when laying it out &mdash; and while our layout arithmetic is cheap and quick, we're also blocking the main thread on expensive text sizing.

We could improve the situation by manually cacheing our subviews' sizes, but that solution comes with its own set of problems.  Just adding `_imageSize` and `_textSize` ivars wouldn't be enough:  for example, if the text were to change, we'd need to recompute its size.  The boilerplate would quickly become untenable.

Further, even with a cache, we'll still be blocking the main thread on sizing *sometimes*.  We could try to shift sizing to a background thread with `dispatch_async()`, but even if our own code is thread-safe, UIView methods are documented to [only work on the main thread](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/index.html):

> Manipulations to your application’s user interface must occur on the main
> thread. Thus, you should always call the methods of the UIView class from
> code running in the main thread of your application. The only time this may
> not be strictly necessary is when creating the view object itself but all
> other manipulations should occur on the main thread.

This is a pretty deep rabbit hole.  We could attempt to work around the fact that UILabels and UITextViews cannot safely be sized on background threads by manually creating a TextKit stack and sizing the text ourselves... but that's a laborious duplication of work.  Further, if UITextView's layout behaviour changes in an iOS update, our sizing code will break.  (And did we mention that TextKit isn't thread-safe either?)

### Manual Layout ASDK

Manual layout within ASDK are realized within two methods:

#### `calculateSizeThatFits` and `layout`

Within `calculateSizeThatFits:` you should provide a intrinsic content size for the node based on the given `constrainedSize`. This method is called on a background thread so perform expensive sizing operations within it.

```Obj-c
- [ASDisplayNode calculateSizeThatFits:]
```

After measurement and layout pass happens further layout can be done in `layout`. This method is called on the main thread. In there, layout operations can be done for nodes that are not playing within the automatic layout system and are referenced within `layoutSpecThatFits:`.

```Obj-c
- [ASDisplayNode layout]
```

#### Example
Our custom node looks like this:

```Obj-c
#import <AsyncDisplayKit/AsyncDisplayKit+Subclasses.h>

...

// perform expensive sizing operations on a background thread
- (CGSize)calculateSizeThatFits:(CGSize)constrainedSize
{
  // size the image
  CGSize imageSize = [_imageNode layoutThatFits:ASSizeRangeMake(CGSizeZero, constrainedSize)].size;

  // size the text node
  CGSize maxTextSize = CGSizeMake(constrainedSize.width - imageSize.width,
                                  constrainedSize.height);

  CGSize textSize = [_textNode layoutThatFits:ASSizeRangeMake(CGSizeZero, maxTextSize)].size;

  // make sure everything fits
  CGFloat minHeight = MAX(imageSize.height, textSize.height);
  return CGSizeMake(constrainedSize.width, minHeight);
}

// do as little work as possible in main-thread layout
- (void)layout
{
  // layout the image using its cached size
  CGSize imageSize = _imageNode.calculatedSize;
  _imageNode.frame = CGRectMake(self.bounds.size.width - imageSize.width, 0.0f,
                                imageSize.width, imageSize.height);

  // layout the text view using its cached size
  CGSize textSize = _textNode.calculatedSize;
  _textNode.frame = (CGRect){ CGPointZero, textSize };
}
```

`ASImageNode` and `ASTextNode`, like the rest of AsyncDisplayKit, are thread-safe, so we can size them on background threads.  The `-layoutThatFits:` method is like `-sizeThatFits:`, but with side effects:  it caches the (`calculatedSize`) for quick access later on &mdash; like in our now-snappy `-layout` implementation.

As you can see, node hierarchies are sized and laid out in much the same way as their view counterparts.  Manually layed out nodes do need to be written with a few things in mind:

* Nodes must recursively measure all of their subnodes in their `-calculateSizeThatFits:` implementations.  Note that the `-layoutThatFits:` machinery will only call `-calculateSizeThatFits:` if a new measurement pass is needed (e.g., if the constrained size has changed) and `layoutSpecThatFits:` is *not* implemented.

* Nodes should perform any other expensive pre-layout calculations in `-calculateSizeThatFits:`, caching useful intermediate results in ivars as appropriate.

* Nodes should call `[self invalidateCalculatedSize]` when necessary.  For example, `ASTextNode` invalidates its calculated size when its `attributedString` property is changed.

As already mentioned, automatic layout is preferred over manual layout and should be the way to go in most cases.
