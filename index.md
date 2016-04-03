---
layout: default
title: A React-inspired view framework for iOS 
id: home
---

<div class="page-content">
            <div class="wrapper">
                <div class="post">
<article class="post-content">
    <p><img src="/static/logo.png" alt="logo"></p>

    <p>AsyncDisplayKit is an iOS framework that keeps even the most complex user
    interfaces smooth and responsive.  It was originally built to make Facebook&#39;s
    <a href="https://facebook.com/paper">Paper</a> possible, and goes hand-in-hand with
    <a href="https://github.com/facebook/pop">pop</a>&#39;s physics-based animations &mdash; but
    it&#39;s just as powerful with UIKit Dynamics and conventional app designs.</p>

    As the framework has grown, many features have been added that can save developers tons of time by eliminating common boilerplate style structures common in modern iOS apps.  

    If you've ever dealt with cell reuse bugs, tried to performantly preload data for a page or scroll style interface or even just tried to keep your app from dropping too many frames you can benefit from integrating ASDK.

    <p><br /></p>

    <h3>Quick start</h3>

    <p>ASDK is available on <a href="http://cocoapods.org">CocoaPods</a>.  Add the following to your Podfile:</p>
    <div class="highlight"><pre><code class="language-ruby" data-lang="ruby"><span class="n">pod</span> <span class="s1">&#39;AsyncDisplayKit&#39;</span>
    </code></pre></div>
    <p>(ASDK can also be used as a regular static library:  Copy the project to your
    codebase manually, adding <code>AsyncDisplayKit.xcodeproj</code> to your workspace.  Add
    <code>libAsyncDisplayKit.a</code>, AssetsLibrary, and Photos to the &quot;Link Binary With
    Libraries&quot; build phase.  Include <code>-lc++ -ObjC</code> in your project linker flags.)</p>

    <p>Import the framework header, or create an <a href="https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html">Objective-C bridging
    header</a>
    if you&#39;re using Swift:</p>
    <div class="highlight"><pre><code class="language-objective-c" data-lang="objective-c"><span class="cp">#import &lt;AsyncDisplayKit/AsyncDisplayKit.h&gt;</span>
    </code></pre></div>
    <p>AsyncDisplayKit Nodes are a thread-safe abstraction layer over UIViews and
    CALayers:</p>

    <p><img src="/static/node-view-layer.png" alt="logo"></p>

    You can access most view and layer properties when using nodes, the difference is that nodes are rendered concurrently by default, and measured and laid out asynchronously when used <a href = "/docs/automatic-layout.html">correctly</a>!
<br/>
<p>
    To learn more, <a href = "/docs/getting-started.html">check out our docs!</a>
</p>
  </article>

</div>
