---
title: ASVideoNode
layout: docs
permalink: /docs/video-node.html
prevPage: map-node.html
nextPage: scroll-node.html
---

`ASVideoNode` is a newer class that exposes a relatively full-featured API, and is designed for both efficient and convenient implementation of embedded videos in scrolling views.

Features:
- supports autoplay (and pause) when items become visible, even if they are in a nested scroller (e.g. an ASPagerNode containing ASTableNodes). 
- asynchronous downloading and decoding of a thumbnail / placeholder image if a URL is provided. If unavailable, it will use hardware frame decoding to display the first video frame. 
- supports HLS (HTTP live streaming) - currently in PR form

Gotchas:
- Applications using ASVideoNode must link AVFoundation!

Examples:
- `examples/videoTableView`
- `examples/videos`
