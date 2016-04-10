---
title: ASMultiplexImageNode
layout: docs
permalink: /docs/multiplex-image-node.html
---
Create components using the `newWithView:size:` class method:

```objc++
+ (instancetype)newWithView:(const CKComponentViewConfiguration &)view
                       size:(const CKComponentSize &)size;
```

It's important to note that you don't pass a `UIView` directly, but a `CKComponentViewConfiguration`. What's that?

```objc++
struct CKComponentViewConfiguration {
  CKComponentViewClass viewClass;
  std::unordered_map<CKComponentViewAttribute, id> attributes;
};
```

The first field is a view class. Ignore `CKComponentViewClass` for now — in most cases you just pass a class like `[UIImageView class]` or `[UIButton class]`.

The second field holds a map of attributes to values: font, color, background image, and so forth. Again, ignore `CKComponentViewAttribute` for now; you can usually use a `SEL` as the attribute.

Let's put one together:

```objc++
[CKComponent 
 newWithView:{
   [UIImageView class],
   {
     {@selector(setImage:), image},
     {@selector(setContentMode:), @(UIViewContentModeCenter)} // Wrapping into an NSNumber
   }
 }
 size:{image.size.width, image.size.height}];
```

That's all there is to it. ComponentKit does this for us:

- Automatically creates or reuses a `UIImageView` when the component is mounted
- Automatically calls `setImage:` and `setContentMode:` with the given values
- Skips calling `setImage:` or `setContentMode:` if the value is unchanged between two updates — the most common case when updating a tree.

## Primitive Arguments

The values in the map are of type `id`, so if you want to pass in primitive types like `BOOL`, you have to wrap them into an `NSValue` object using e.g. `@(value)` and ComponentKit will unwrap them.

## Viewless Components

Often there exist logical components that don't need a corresponding view in the view hierarchy. For example a `CKStackLayoutComponent` often doesn't need to have a view; it only needs to position various subviews inside a designated area. In such situations, just pass `{}` for the view configuration and no view is created. For example:

```objc++
[CKComponent newWithView:{} size:{}]
```

(You can also just use `+new` directly, which uses this as the default.)

## Advanced Views

This is sufficient for most cases, but there is considerably more power when you need it. See [Advanced Views](advanced-views.html) if you want to learn more.
