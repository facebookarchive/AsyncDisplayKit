---
title: ASMapNode
layout: docs
permalink: /docs/map-node.html
---

`ASMapNode` offers completely asynchronous preparation, automatic preloading, and efficient memory handling. Its standard mode is a fully asynchronous snapshot, with liveMap mode loading automatically triggered by any `ASTableView` or `ASCollectionView`; its `.liveMap` mode can be flipped on with ease (even on a background thread) to provide a cached, fully interactive map when necessary. 

Features:
- uses `MKMapSnapshotOptions` as its primary specification format for map details. Among other things, this allows specifying 3D camera angles for snapshots loaded automatically and asynchronously while scrolling, with seamless transitions to an interactive map.

Gotchas:
- the liveMap mode is backed by a MKMapView which is NOT thread-safe
