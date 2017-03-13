---
title: Layout Element Properties
layout: docs
permalink: /docs/layout2-layout-element-properties.html
prevPage: layout2-layoutspec-types.html
nextPage: layout2-api-sizing.html
---

- <a href="layout2-layout-element-properties.html#asstacklayoutelement-properties">ASStackLayoutElement Properties</a> - will only take effect on a node or layout spec that is the child of a <b>stack</b> spec
- <a href="layout2-layout-element-properties.html#asabsolutelayoutelement-properties">ASAbsoluteLayoutElement Properties</a> - will only take effect on a node or layout spec that is the child of a <b>absolute</b> spec
- <a href="layout2-layout-element-properties.html#aslayoutelement-properties">ASLayoutElement Properties</a> - applies to all nodes & layout specs

## ASStackLayoutElement Properties

<div class = "note">
<b>Please note that the following properties will only take effect if set on the child of an <a href="layout2-layoutspec-types.html#asstacklayoutspec-flexbox-container">STACK</a> layout spec.</b>
</div>

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>Property</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b>`CGFloat .style.spacingBefore`</b></td>
    <td>Additional space to place before this object in the stacking direction.</td> 
  </tr>
  <tr>
    <td><b>`CGFloat .style.spacingAfter`</b></td>
    <td>Additional space to place after this object in the stacking direction.</td> 
  </tr>
  <tr>
    <td><b>`BOOL .style.flexGrow`</b></td>
    <td>If the sum of childrens' stack dimensions is less than the minimum size, should this object grow?</td> 
  </tr>
  <tr>
    <td><b>`BOOL .style.flexShrink`</b></td>
    <td>If the sum of childrens' stack dimensions is greater than the maximum size, should this object shrink?</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.flexBasis`</b></td>
    <td>Specifies the initial size for this object, in the stack dimension (horizontal or vertical), before the `flexGrow` / `flexShrink` properties are applied and the remaining space is distributed. </td> 
  </tr>
  <tr>
    <td><b>`ASStackLayoutAlignSelf .style.alignSelf`</b></td>
    <td>Orientation of the object along cross axis, overriding alignItems. Options include: 
    <ul>
    <li>`ASStackLayoutAlignSelfAuto`</li>
    <li>`ASStackLayoutAlignSelfStart`</li>
    <li>`ASStackLayoutAlignSelfEnd`</li>
    <li>`ASStackLayoutAlignSelfCenter`</li>
    <li>`ASStackLayoutAlignSelfStretch`</li>
    </ul></td> 
  </tr>
  <tr>
    <td><b>`CGFloat .style.ascender`</b></td>
    <td>Used for baseline alignment. The distance from the top of the object to its baseline.</td> 
  </tr>
  <tr>
    <td><b>`CGFloat .style.descender`</b></td>
    <td>Used for baseline alignment. The distance from the baseline of the object to its bottom.</td> 
  </tr>
</table> 


## ASAbsoluteLayoutElement Properties

<div class = "note">
<b>Please note that the following properties will only take effect if set on the child of an <a href="layout2-layoutspec-types.html#asabsolutelayoutspec">ABSOLUTE</a> layout spec.</b>
</div>

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>Property</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b>`CGPoint .style.layoutPosition`</b></td>
    <td>The `CGPoint` position of this object within its `ASAbsoluteLayoutSpec` parent spec.</td> 
  </tr>
</table>

## ASLayoutElement Properties

<div class = "note">
<b>Please note that the following properties apply to <b>ALL</b> layout elements.</b>
</div>

<table style="width:100%"  class = "paddingBetweenCols">
  <tr>
    <th>Property</th>
    <th>Description</th> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.width`</b></td>
    <td>The `width` property specifies the width of the content area of an `ASLayoutElement`. The `minWidth` and `maxWidth` properties override `width`. Defaults to `ASDimensionAuto`.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.height`</b></td>
    <td>The `height` property specifies the height of the content area of an `ASLayoutElement`. The `minHeight` and `maxHeight` properties override `height`. Defaults to `ASDimensionAuto`.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.minWidth`</b></td>
    <td>The `minWidth` property is used to set the minimum width of a given element. It prevents the used value of the `width` property from becoming smaller than the value specified for `minWidth`. The value of `minWidth` overrides both `maxWidth` and `width`. Defaults to `ASDimensionAuto`.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.maxWidth`</b></td>
    <td>The `maxWidth` property is used to set the maximum width of a given element. It prevents the used value of the `width` property from becoming larger than the value specified for `maxWidth`. The value of `maxWidth` overrides `width`, but `minWidth` overrides `maxWidth`. Defaults to `ASDimensionAuto`.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.minHeight`</b></td>
    <td>The `minHeight` property is used to set the minimum height of a given element. It prevents the used value of the `height` property from becoming smaller than the value specified for `minHeight`. The value of `minHeight` overrides both `maxHeight` and `height`. Defaults to `ASDimensionAuto`.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#values-cgfloat-asdimension">ASDimension</a> .style.maxHeight`</b></td>
    <td>The `maxHeight` property is used to set the maximum height of a given element. It prevents the used value of the `height` property from becoming larger than the value specified for `maxHeight`. The value of `maxHeight` overrides `height`, but `minHeight` overrides `maxHeight`. Defaults to `ASDimensionAuto`</td> 
  </tr>
  <tr>
    <td><b>`CGSize .style.preferredSize`</b></td>
    <td><p>Provides a suggested size for a layout element. If the optional minSize or maxSize are provided, and the preferredSize exceeds these, the minSize or maxSize will be enforced. If this optional value is not provided, the layout element’s size will default to it’s intrinsic content size provided calculateSizeThatFits:</p>
    <p>This method is optional, but one of either preferredSize or preferredLayoutSize is required for nodes that either have no intrinsic content size or  should be laid out at a different size than its intrinsic content size. For example, this property could be set on an ASImageNode to display at a size different from the underlying image size.</p>
    <p> Warning: calling the getter when the size's width or height are relative will cause an assert.</p></td> 
  </tr>
  <tr>
    <td><b>`CGSize .style.minSize`</b></td>
    <td><p>An optional property that provides a minimum size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s minimum size is smaller than its child’s minimum size, the child’s minimum size will be enforced and its size will extend out of the layout spec’s. </p>
    <p>For example, if you set a preferred relative width of 50% and a minimum width of 200 points on an element in a full screen container, this would result in a width of 160 points on an iPhone screen. However,  since 160 pts is lower than the minimum width of 200 pts, the minimum width would be used.</p></td> 
  </tr>
  <tr>
    <td><b>`CGSize .style.maxSize`</b></td>
    <td><p>An optional property that provides a maximum size bound for a layout element. If provided, this restriction will always be enforced.  If a child layout element’s maximum size is smaller than its parent, the child’s maximum size will be enforced and its size will extend out of the layout spec’s. </p>
    <p>For example, if you set a preferred relative width of 50% and a maximum width of 120 points on an element in a full screen container, this would result in a width of 160 points on an iPhone screen. However,  since 160 pts is higher than the maximum width of 120 pts, the maximum width would be used.</p></td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#sizes-cgsize-aslayoutsize">ASLayoutSize</a> .style.preferredLayoutSize`</b></td>
    <td>Provides a suggested RELATIVE size for a layout element. An ASLayoutSize uses percentages rather than points to specify layout. E.g. width should be 50% of the parent’s width. If the optional minLayoutSize or maxLayoutSize are provided, and the preferredLayoutSize exceeds these, the minLayoutSize or maxLayoutSize will be enforced. If this optional value is not provided, the layout element’s size will default to its intrinsic content size provided `calculateSizeThatFits:`</td>
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#sizes-cgsize-aslayoutsize">ASLayoutSize</a> .style.minLayoutSize`</b></td>
    <td>An optional property that provides a minimum RELATIVE size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s minimum relative size is smaller than its child’s minimum relative size, the child’s minimum relative size will be enforced and its size will extend out of the layout spec’s.</td> 
  </tr>
  <tr>
    <td><b>`<a href="layout2-api-sizing.html#sizes-cgsize-aslayoutsize">ASLayoutSize</a> .style.maxLayoutSize`</b></td>
    <td>An optional property that provides a maximum RELATIVE size bound for a layout element. If provided, this restriction will always be enforced. If a parent layout element’s maximum relative size is smaller than its child’s maximum relative size, the child’s maximum relative size will be enforced and its size will extend out of the layout spec’s.</td> 
  </tr>
</table> 
