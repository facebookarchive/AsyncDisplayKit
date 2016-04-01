---
title: Subclassing 
layout: docs
permalink: /docs/subclassing.html
---

<article class="post-content">
    <h2>View hierarchies</h2>

<p>Sizing and layout of custom view hierarchies are typically done all at once on
the main thread.  For example, a custom UIView that minimally encloses a text
view and an image view might look like this:</p>
<div class="highlight"><pre><code class="language-objective-c" data-lang="objective-c"><span class="p">-</span> <span class="p">(</span><span class="bp">CGSize</span><span class="p">)</span><span class="nf">sizeThatFits:</span><span class="p">(</span><span class="bp">CGSize</span><span class="p">)</span><span class="nv">size</span>
<span class="p">{</span>
  <span class="c1">// size the image</span>
  <span class="bp">CGSize</span> <span class="n">imageSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_imageView</span> <span class="nl">sizeThatFits</span><span class="p">:</span><span class="n">size</span><span class="p">];</span>

  <span class="c1">// size the text view</span>
  <span class="bp">CGSize</span> <span class="n">maxTextSize</span> <span class="o">=</span> <span class="n">CGSizeMake</span><span class="p">(</span><span class="n">size</span><span class="p">.</span><span class="n">width</span> <span class="o">-</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">size</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>
  <span class="bp">CGSize</span> <span class="n">textSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_textView</span> <span class="nl">sizeThatFits</span><span class="p">:</span><span class="n">maxTextSize</span><span class="p">];</span>

  <span class="c1">// make sure everything fits</span>
  <span class="n">CGFloat</span> <span class="n">minHeight</span> <span class="o">=</span> <span class="n">MAX</span><span class="p">(</span><span class="n">imageSize</span><span class="p">.</span><span class="n">height</span><span class="p">,</span> <span class="n">textSize</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>
  <span class="k">return</span> <span class="n">CGSizeMake</span><span class="p">(</span><span class="n">size</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">minHeight</span><span class="p">);</span>
<span class="p">}</span>

<span class="p">-</span> <span class="p">(</span><span class="kt">void</span><span class="p">)</span><span class="nf">layoutSubviews</span>
<span class="p">{</span>
  <span class="bp">CGSize</span> <span class="n">size</span> <span class="o">=</span> <span class="nb">self</span><span class="p">.</span><span class="n">bounds</span><span class="p">.</span><span class="n">size</span><span class="p">;</span> <span class="c1">// convenience</span>

  <span class="c1">// size and layout the image</span>
  <span class="bp">CGSize</span> <span class="n">imageSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_imageView</span> <span class="nl">sizeThatFits</span><span class="p">:</span><span class="n">size</span><span class="p">];</span>
  <span class="n">_imageView</span><span class="p">.</span><span class="n">frame</span> <span class="o">=</span> <span class="n">CGRectMake</span><span class="p">(</span><span class="n">size</span><span class="p">.</span><span class="n">width</span> <span class="o">-</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="mf">0.0f</span><span class="p">,</span>
                                <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>

  <span class="c1">// size and layout the text view</span>
  <span class="bp">CGSize</span> <span class="n">maxTextSize</span> <span class="o">=</span> <span class="n">CGSizeMake</span><span class="p">(</span><span class="n">size</span><span class="p">.</span><span class="n">width</span> <span class="o">-</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">size</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>
  <span class="bp">CGSize</span> <span class="n">textSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_textView</span> <span class="nl">sizeThatFits</span><span class="p">:</span><span class="n">maxTextSize</span><span class="p">];</span>
  <span class="n">_textView</span><span class="p">.</span><span class="n">frame</span> <span class="o">=</span> <span class="p">(</span><span class="bp">CGRect</span><span class="p">){</span> <span class="n">CGPointZero</span><span class="p">,</span> <span class="n">textSize</span> <span class="p">};</span>
<span class="p">}</span>
</code></pre></div>
<p>This isn&#39;t ideal.  We&#39;re sizing our subviews twice &mdash; once to figure out
how big our view needs to be and once when laying it out &mdash; and while our
layout arithmetic is cheap and quick, we&#39;re also blocking the main thread on
expensive text sizing.</p>

<p>We could improve the situation by manually cacheing our subviews&#39; sizes, but
that solution comes with its own set of problems.  Just adding <code>_imageSize</code> and
<code>_textSize</code> ivars wouldn&#39;t be enough:  for example, if the text were to change,
we&#39;d need to recompute its size.  The boilerplate would quickly become
untenable.</p>

<p>Further, even with a cache, we&#39;ll still be blocking the main thread on sizing
<em>sometimes</em>.  We could try to shift sizing to a background thread with
<code>dispatch_async()</code>, but even if our own code is thread-safe, UIView methods are
documented to <a href="https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIView_Class/index.html">only work on the main
thread</a>:</p>

<blockquote>
Manipulations to your application’s user interface must occur on the main
thread. Thus, you should always call the methods of the UIView class from
code running in the main thread of your application. The only time this may
not be strictly necessary is when creating the view object itself but all
other manipulations should occur on the main thread.
</blockquote>

<p>This is a pretty deep rabbit hole.  We could attempt to work around the fact
that UILabels and UITextViews cannot safely be sized on background threads by
manually creating a TextKit stack and sizing the text ourselves... but that&#39;s a
laborious duplication of work.  Further, if UITextView&#39;s layout behaviour
changes in an iOS update, our sizing code will break.  (And did we mention that
TextKit isn&#39;t thread-safe either?)</p>

<h2>Node hierarchies</h2>

<p>Enter AsyncDisplayKit.  Our custom node looks like this:</p>
<div class="highlight"><pre><code class="language-objective-c" data-lang="objective-c"><span class="cp">#import &lt;AsyncDisplayKit/AsyncDisplayKit+Subclasses.h&gt;</span>

<span class="p">...</span>

<span class="c1">// perform expensive sizing operations on a background thread</span>
<span class="o">-</span> <span class="p">(</span><span class="bp">CGSize</span><span class="p">)</span><span class="nl">calculateSizeThatFits</span><span class="p">:(</span><span class="bp">CGSize</span><span class="p">)</span><span class="n">constrainedSize</span>
<span class="p">{</span>
  <span class="c1">// size the image</span>
  <span class="bp">CGSize</span> <span class="n">imageSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_imageNode</span> <span class="nl">measure</span><span class="p">:</span><span class="n">constrainedSize</span><span class="p">];</span>

  <span class="c1">// size the text node</span>
  <span class="bp">CGSize</span> <span class="n">maxTextSize</span> <span class="o">=</span> <span class="n">CGSizeMake</span><span class="p">(</span><span class="n">constrainedSize</span><span class="p">.</span><span class="n">width</span> <span class="o">-</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span>
                                  <span class="n">constrainedSize</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>
  <span class="bp">CGSize</span> <span class="n">textSize</span> <span class="o">=</span> <span class="p">[</span><span class="n">_textNode</span> <span class="nl">measure</span><span class="p">:</span><span class="n">maxTextSize</span><span class="p">];</span>

  <span class="c1">// make sure everything fits</span>
  <span class="n">CGFloat</span> <span class="n">minHeight</span> <span class="o">=</span> <span class="n">MAX</span><span class="p">(</span><span class="n">imageSize</span><span class="p">.</span><span class="n">height</span><span class="p">,</span> <span class="n">textSize</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>
  <span class="k">return</span> <span class="nf">CGSizeMake</span><span class="p">(</span><span class="n">constrainedSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">minHeight</span><span class="p">);</span>
<span class="p">}</span>

<span class="c1">// do as little work as possible in main-thread layout</span>
<span class="o">-</span> <span class="p">(</span><span class="kt">void</span><span class="p">)</span><span class="n">layout</span>
<span class="p">{</span>
  <span class="c1">// layout the image using its cached size</span>
  <span class="bp">CGSize</span> <span class="n">imageSize</span> <span class="o">=</span> <span class="n">_imageNode</span><span class="p">.</span><span class="n">calculatedSize</span><span class="p">;</span>
  <span class="n">_imageNode</span><span class="p">.</span><span class="n">frame</span> <span class="o">=</span> <span class="n">CGRectMake</span><span class="p">(</span><span class="nb">self</span><span class="p">.</span><span class="n">bounds</span><span class="p">.</span><span class="n">size</span><span class="p">.</span><span class="n">width</span> <span class="o">-</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="mf">0.0f</span><span class="p">,</span>
                                <span class="n">imageSize</span><span class="p">.</span><span class="n">width</span><span class="p">,</span> <span class="n">imageSize</span><span class="p">.</span><span class="n">height</span><span class="p">);</span>

  <span class="c1">// layout the text view using its cached size</span>
  <span class="bp">CGSize</span> <span class="n">textSize</span> <span class="o">=</span> <span class="n">_textNode</span><span class="p">.</span><span class="n">calculatedSize</span><span class="p">;</span>
  <span class="n">_textNode</span><span class="p">.</span><span class="n">frame</span> <span class="o">=</span> <span class="p">(</span><span class="bp">CGRect</span><span class="p">){</span> <span class="n">CGPointZero</span><span class="p">,</span> <span class="n">textSize</span> <span class="p">};</span>
<span class="p">}</span>
</code></pre></div>
<p>ASImageNode and ASTextNode, like the rest of AsyncDisplayKit, are thread-safe,
so we can size them on background threads.  The <code>-measure:</code> method is like
<code>-sizeThatFits:</code>, but with side effects:  it caches both the argument
(<code>constrainedSizeForCalculatedSize</code>) and the result (<code>calculatedSize</code>) for
quick access later on &mdash; like in our now-snappy <code>-layout</code> implementation.</p>

<p>As you can see, node hierarchies are sized and laid out in much the same way as
their view counterparts.  Custom nodes do need to be written with a few things
in mind:</p>

<ul>
<li><p>Nodes must recursively measure all of their subnodes in their
<code>-calculateSizeThatFits:</code> implementations.  Note that the <code>-measure:</code>
machinery will only call <code>-calculateSizeThatFits:</code> if a new measurement pass
is needed (e.g., if the constrained size has changed).</p></li>
<li><p>Nodes should perform any other expensive pre-layout calculations in
<code>-calculateSizeThatFits:</code>, cacheing useful intermediate results in ivars as
appropriate.</p></li>
<li><p>Nodes should call <code>[self invalidateCalculatedSize]</code> when necessary.  For
example, ASTextNode invalidates its calculated size when its
<code>attributedString</code> property is changed.</p></li>
</ul>

<p>For more examples of custom sizing and layout, along with a demo of
ASTextNode&#39;s features, check out <code>BlurbNode</code> and <code>KittenNode</code> in the
<a href="https://github.com/facebook/AsyncDisplayKit/tree/master/examples/Kittens">Kittens</a>
sample project.</p>

<h2>Custom drawing</h2>

<p>To guarantee thread safety in its highly-concurrent drawing system, the node
drawing API diverges substantially from UIView&#39;s.  Instead of implementing
<code>-drawRect:</code>, you must:</p>

<ol>
<li><p>Define an internal &quot;draw parameters&quot; class for your custom node.  This
class should be able to store any state your node needs to draw itself
&mdash; it can be a plain old NSObject or even a dictionary.</p></li>
<li><p>Return a configured instance of your draw parameters class in
<code>-drawParametersForAsyncLayer:</code>.  This method will always be called on the
main thread.</p></li>
<li><p>Implement either <code>+drawRect:withParameters:isCancelled:isRasterizing:</code> or
<code>+displayWithParameters:isCancelled:</code>.  Note that these are <em>class</em> methods
that will not have access to your node&#39;s state &mdash; only the draw
parameters object.  They can be called on any thread and must be
thread-safe.</p></li>
</ol>

<p>For example, this node will draw a rainbow:</p>
<div class="highlight"><pre><code class="language-objective-c" data-lang="objective-c"><span class="k">@interface</span> <span class="nc">RainbowNode</span> : <span class="nc">ASDisplayNode</span>
<span class="k">@end</span>

<span class="k">@implementation</span> <span class="nc">RainbowNode</span>

<span class="p">+</span> <span class="p">(</span><span class="kt">void</span><span class="p">)</span><span class="nf">drawRect:</span><span class="p">(</span><span class="bp">CGRect</span><span class="p">)</span><span class="nv">bounds</span>
  <span class="nf">withParameters:</span><span class="p">(</span><span class="kt">id</span><span class="o">&lt;</span><span class="bp">NSObject</span><span class="o">&gt;</span><span class="p">)</span><span class="nv">parameters</span>
     <span class="nf">isCancelled:</span><span class="p">(</span><span class="kt">asdisplaynode_iscancelled_block_t</span><span class="p">)</span><span class="nv">isCancelledBlock</span>
   <span class="nf">isRasterizing:</span><span class="p">(</span><span class="kt">BOOL</span><span class="p">)</span><span class="nv">isRasterizing</span>
<span class="p">{</span>
  <span class="c1">// clear the backing store, but only if we&#39;re not rasterising into another layer</span>
  <span class="k">if</span> <span class="p">(</span><span class="o">!</span><span class="n">isRasterizing</span><span class="p">)</span> <span class="p">{</span>
    <span class="p">[[</span><span class="bp">UIColor</span> <span class="n">whiteColor</span><span class="p">]</span> <span class="n">set</span><span class="p">];</span>
    <span class="n">UIRectFill</span><span class="p">(</span><span class="n">bounds</span><span class="p">);</span>
  <span class="p">}</span>

  <span class="c1">// UIColor sadly lacks +indigoColor and +violetColor methods</span>
  <span class="bp">NSArray</span> <span class="o">*</span><span class="n">colors</span> <span class="o">=</span> <span class="l">@[</span> <span class="p">[</span><span class="bp">UIColor</span> <span class="n">redColor</span><span class="p">],</span>
                       <span class="p">[</span><span class="bp">UIColor</span> <span class="n">orangeColor</span><span class="p">],</span>
                       <span class="p">[</span><span class="bp">UIColor</span> <span class="n">yellowColor</span><span class="p">],</span>
                       <span class="p">[</span><span class="bp">UIColor</span> <span class="n">greenColor</span><span class="p">],</span>
                       <span class="p">[</span><span class="bp">UIColor</span> <span class="n">blueColor</span><span class="p">],</span>
                       <span class="p">[</span><span class="bp">UIColor</span> <span class="n">purpleColor</span><span class="p">]</span> <span class="l">]</span><span class="p">;</span>
  <span class="n">CGFloat</span> <span class="n">stripeHeight</span> <span class="o">=</span> <span class="n">roundf</span><span class="p">(</span><span class="n">bounds</span><span class="p">.</span><span class="n">size</span><span class="p">.</span><span class="n">height</span> <span class="o">/</span> <span class="p">(</span><span class="kt">float</span><span class="p">)</span><span class="n">colors</span><span class="p">.</span><span class="n">count</span><span class="p">);</span>

  <span class="c1">// draw the stripes</span>
  <span class="k">for</span> <span class="p">(</span><span class="bp">UIColor</span> <span class="o">*</span><span class="n">color</span> <span class="k">in</span> <span class="n">colors</span><span class="p">)</span> <span class="p">{</span>
    <span class="bp">CGRect</span> <span class="n">stripe</span> <span class="o">=</span> <span class="n">CGRectZero</span><span class="p">;</span>
    <span class="n">CGRectDivide</span><span class="p">(</span><span class="n">bounds</span><span class="p">,</span> <span class="o">&amp;</span><span class="n">stripe</span><span class="p">,</span> <span class="o">&amp;</span><span class="n">bounds</span><span class="p">,</span> <span class="n">stripeHeight</span><span class="p">,</span> <span class="n">CGRectMinYEdge</span><span class="p">);</span>
    <span class="p">[</span><span class="n">color</span> <span class="n">set</span><span class="p">];</span>
    <span class="n">UIRectFill</span><span class="p">(</span><span class="n">stripe</span><span class="p">);</span>
  <span class="p">}</span>
<span class="p">}</span>

<span class="k">@end</span>
</code></pre></div>
<p>This could easily be extended to support vertical rainbows too, by adding a
<code>vertical</code> property to the node, exporting it in
<code>-drawParametersForAsyncLayer:</code>, and referencing it in
<code>+drawRect:withParameters:isCancelled:isRasterizing:</code>. More-complex nodes can
be supported in much the same way.</p>

<p>For more on custom nodes, check out the <a href="https://github.com/facebook/AsyncDisplayKit/blob/master/AsyncDisplayKit/ASDisplayNode%2BSubclasses.h">subclassing
header</a>
or read on!</p>

    </article>