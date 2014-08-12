# AsyncDisplayKit

---

Welcome to the AsyncDisplayKit beta!  Documentation — including this README — will be fleshed out for the initial public release.  Until then, please direct questions and feedback to the [Paper Engineering Community](https://www.facebook.com/groups/551597518288687) group.

---


AsyncDisplayKit is a library for smooth asynchronous user interfaces on iOS.

UIKit traditionally only runs on the main thread. This includes expensive tasks like text sizing and rendering, as well as image decoding. 

AsyncDisplayKit can handle all of the expensive parts asynchronously on a background thread, caching the values before actual views are created, and finally laying out views or layers efficiently on the main thread.

AsyncDisplayKit uses display nodes to represent views and layers. The node API is designed to be as similar as possible to UIKit's. 


## Install

AsyncDisplayKit is available on [CocoaPods](http://cocoapods.org/).  You can manually include it in your project's Podfile:

	pod 'AsyncDisplayKit', :git => 'git@github.com:facebook/AsyncDisplayKit.git'

and run 

	pod install


## Usage

Start by importing the header:

	#import <AsyncDisplayKit/AsyncDisplayKit.h>

An _ASDisplayNode_ is an abstraction over _UIView_ and _CALayer_ that allows you to perform calculations about a view hierarchy off the main thread. The node API is designed to be as similar as possible to UIView.

_ASDisplayNode_ can be allocated, initialized and its properties can be set all on a background thread.

	dispatch_async(background_queue, ^{
	
		n = [[ASDisplayNode alloc] init];
		n.frame = CGRectMake(0, 40, 100, 100);
		n.backgroundColor = [UIColor greenColor];
		
	});

Hierarchies can be created in a similar way as UIKit:

	dispatch_async(background_queue, ^{
		
		s = [[ASDisplayNode alloc] init];
		[n addSubNode:s];
		
	});

A node may be backed by a view or layer, which must take place on the main thread. At this point, views may read their cached calculatedSize when performing layout.

	dispatch_async(dispatch_get_main_queue(), ^{
	
		UIView *v = [node view];
	
		// You can now add it to the view hierarchy
		[someView addSubview:v];

		// The properties you set earlier will be preserved
		// v.frame is {0, 40, 100, 100}
		// v.backgroundColor is green
	});
	
Besides _ASDisplayNode_, AsyncDisplayKit has UIKit equivalent classes:

- _ASControlNode_: a UIButton equivalent
- _ASTextNode_: a UITextView equivalent, with features like tap highlights, custom truncation strings, gradients, shadows, and tappable links.
- _ASImageNode_: a UIImageView equivalent

Node-aware UITableView and UICollectionView implementations are currently planned, but not yet implemented.


## Documentation 

See the [wiki](https://github.com/facebook/AsyncDisplayKit/wiki) for more details on use cases, performance, subclassing, bridged properties, sizing and layout, and UIKit divergence.


## Testing

AsyncDisplayKit has extensive unit test coverage.  You'll need to run `pod install` in the root AsyncDisplayKit directory to set up OCMock.

## Contributing

See the CONTRIBUTING file for how to help out.

## License

AsyncDisplayKit is BSD-licensed.  We also provide an additional patent grant.
