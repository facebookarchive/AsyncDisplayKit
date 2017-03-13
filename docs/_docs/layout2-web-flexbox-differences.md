---
title: Web Flexbox Differences
layout: docs
permalink: /docs/layout2-web-flexbox-differences.html
---

The goal of AsyncDisplayKit's Layout API is *not* to re-implement all of CSS. It only targets a subset of CSS and Flexbox container, and there are no plans to implement support for tables, floats, or any other CSS concepts. The AsyncDisplayKit Layout API also does not plan to support styling properties which do not affect layout such as color or background properties.

The layout system tries to stay as close as possible to CSS. There are, however, certain cases where it differs from the web, these include:

### Naming properties

Certain properties have a different naming as on the web. For example `min-height` equivalent is the `minHeight` property. The full list of properties that control layout is documented in the Layout Properties section.

### No margin / padding properties

Layoutables don't have a padding or margin property. Instead wrapping a layoutable within an `ASInsetLayoutSpec` to apply padding or margin to the layoutable is the recommended way. See `ASInsetLayout` section for more information.

### Missing features

Certain features like `flexWrap` on a `ASStackLayoutSpec` are not supported currently. See <a href = "layout2-properties.html">Layout Properties</a> for the full list of properties that are supported.