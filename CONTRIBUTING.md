# Contribution Guidelines
Texture is the most actively developed open source project at [Pinterest](https://www.pinterest.com) and is used extensively to deliver a world-class Pinner experience. This document is setup to ensure contributing to the project is easy and transparent.

# Questions

If you are having difficulties using Texture or have a question about usage, please ask a
question in our [Slack channel](http://texturegroup.org/slack.html). **Please do not ask for help by filing Github issues.**

# Core Team

The Core Team reviews and helps iterate on the RFC Issues from the community at large and acting as the approver of these RFCs. Team members help drive Texture forward in a coherent direction consistent with the goal of creating the best possible general purpose UI framework for iOS. Team members will have merge permissions on the repository.

Members of the core team are appointed based on their technical expertise and proven contribution to the community. The current core team members are:

- Adlai Holler ([@](http://github.com/adlai-holler)[adlai-holler](http://github.com/adlai-holler))
- Garrett Moon [(](https://github.com/garrettmoon)[@](https://github.com/garrettmoon)[garrett](https://github.com/garrettmoon)[moon](https://github.com/garrettmoon))
- Huy Nguyen ([@](https://github.com/nguyenhuy)[nguyenhuy](https://github.com/nguyenhuy))
- Michael Schneider ([@maicki](https://github.com/maicki))
- Scott Goodson ([@appleguy](https://github.com/appleguy))

Over time, exceptional community members from a much more diverse background will be appointed based on their record of community involvement and contributions.

# Issues

Think you've found a bug or have a new feature to suggest? [Let us know](https://github.com/TextureGroup/Texture/issues/new)!

## Where to Find Known Issues

We use [GitHub Issues](https://github.com/texturegroup/texture/issues) for all bug tracking. We keep a close eye on this and try to make it clear when we have an internal fix in progress. Before filing a new issue, try to make sure your problem doesn't already exist.

## Reporting New Issues
1. Update to the most recent master release if possible. We may have already fixed your bug.
2. Search for similar [issues](https://github.com/TextureGroup/Texture/issues). It's possible somebody has encountered this bug already.
3. Provide a reduced test case that specifically shows the problem. This demo should be fully operational with the exception of the bug you want to demonstrate. The more pared down, the better. If it is not possible to produce a test case, please make sure you provide very specific steps to reproduce the error. If we cannot reproduce it, and there is no other evidence to help us figure out a fix we will close the issue.
4. Your issue will be verified. The provided example will be tested for correctness. The Texture team will work with you until your issue can be verified.
5. Keep up to date with feedback from the Texture team on your issue. Your issue may be closed if it becomes stale.
6. If possible, submit a Pull Request with a failing test. Better yet, take a stab at fixing the bug yourself if you can!

The more information you provide, the easier it is for us to validate that there is a bug and the faster we'll be able to take action.

## Issues Triaging
- You might be requested to provide a reproduction or extra information. In that case, the issue will be labeled as **N****eeds More Info**. If we did not get any response after fourteen days, we will ping you to remind you about it. We might close the issue if we do not hear from you after two weeks since the original notice.
- If you submit a feature request as a GitHub issue, you will be invited to follow the instructions in this section otherwise the issue will be closed.
- Issues that become inactive will be labelled accordingly to inform the original poster and Texture contributors that the issue should be closed since the issue is no longer actionable. The issue can be reopened at a later time if needed, e.g. becomes actionable again.
- If possible, issues will be labeled to indicate the status or priority. For example, labels may have a prefix for Status: X, or Priority: X. Statuses may include: In Progress, On Hold. Priorities may include: P1, P2 or P3 (high to low priority).
# Requesting a Feature

If you intend to change the public API, or make any non-trivial changes to the implementation, we recommend filing an RFC [issue](https://github.com/TextureGroup/Texture/issues/new) outlined below. This lets us reach an agreement on your proposal before you put significant effort into implementing it.

If you're only fixing a bug, it's fine to submit a pull request right away, but we still recommend to file an issue detailing what you're fixing. This is helpful in case we don't accept that specific fix but want to keep track of the issue.

## RFC Issue process
1. Texture has an RFC process for feature requests. To begin the discussion either gather feedback on the Texture Slack channel or draft an Texture RFC as a Github Issue.
2. The title of the GitHub RFC Issue should have `[RFC]` as prefix: `[RFC] Add new cool feature`
3. Provide a clear and detailed explanation of the feature you want and why it's important to add. Keep in mind that we want features that will be useful to the majority of our users and not just a small subset. If you're just targeting a minority of users, consider writing an add-on library for Texture.
4. If the feature is complex, consider writing an Texture RFC issue. Even if you can’t implement the feature yourself, consider writing an RFC issue. If we do end up accepting the feature, the issue provides the needed documentation for contributors to develop the feature according the specification accepted by the core team. We will tag accepted RFC issues with **Needs Volunteer**.
5. After discussing the feature you may choose to attempt a Pull Request. If you're at all able, start writing some code. We always have more work to do than time to do it. If you can write some code then that will speed the process along.

In short, if you have an idea that would be nice to have, create an issue on the [TextureGroup](https://github.com/TextureGroup/Texture)[/](https://github.com/TextureGroup/Texture)[Texture](https://github.com/TextureGroup/Texture) repo. If you have a question about requesting a feature, start a discussion in our [Slack channel](http://texturegroup.org/slack.html).

# Our Development Process

All work on Texture happens directly on [GitHub](https://github.com/TextureGroup/Texture). Both core team members and external contributors send pull requests which go through the same review process.

## `master` is under active development

We will do our best to keep master in good shape, with tests passing at all times. But in order to move fast, we will make API changes that your application might not be compatible with. We will do our best to communicate these changes and version appropriately so you can lock into a specific version if need be.

## Pull Requests

If you send a pull request, please do it against the master branch. We maintain stable branches for major versions separately but we don't accept pull requests to them directly. Instead, we cherry-pick non-breaking changes from master to the latest stable major version.

Before submitting a pull request, please make sure the following is done…

1. Search GitHub for an open or closed [pull request](https://github.com/TextureGroup/Texture/pulls?utf8=✓&q=is%3Apr) that relates to your submission. You don't want to duplicate effort.
2. Fork the [repo](https://github.com/TextureGroup/Texture) and create your branch from master:
    git checkout -b my-fix-branch master
3. Create your patch, including appropriate test cases. Please follow our Coding Guidelines.
4. Please make sure every commit message are meaningful so it that makes it clearer for people to review and easier to understand your intention
5. Ensure tests pass CI on GitHub for your Pull Request.
6. If you haven't already, sign the CLA.

**Copyright Notice for files**
Copy and paste this to the top of your new file(s):
```objc
//
//  ASDisplayNode.mm
//  Texture
//
//  Copyright (c) 2017-present, Pinterest, Inc.  All rights reserved.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//      http://www.apache.org/licenses/LICENSE-2.0
//  
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
```

If you’ve modified an existing file, change the header to:
```objc
//
//  ASDisplayNode.mm
//  Texture
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//  Modifications to this file made after 4/13/2017 are: Copyright (c) 2017-present,
//  Pinterest, Inc.  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//  
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
```

# Semantic Versioning

Texture follows semantic versioning. We release patch versions for bug fixes, minor versions for new features (and rarely, clear and easy to fix breaking changes), and major versions for any major breaking changes. When we make breaking changes, we also introduce deprecation warnings in a minor version so that our users learn about the upcoming changes and migrate their code in advance.

We tag every pull request with a label marking whether the change should go in the next patch, minor, or a major version. We release new versions pretty regularly usually every few weeks. The version will be a patch or minor version if it does not contain major new features or breaking API changes and a major version if it does.

# Coding Guidelines
- Indent using 2 spaces (this conserves space in print and makes line wrapping less likely). Never indent with tabs. Be sure to set this preference in Xcode.
- Do your best to keep it around 120 characters line length
- End files with a newline.
- Don’t leave trailing whitespace.
- Space after `@property` declarations and conform to ordering of attributes
```objc
@property (nonatomic, readonly, assign, getter=isTracking) BOOL tracking;
@property (nonatomic, readwrite, strong, nullable) NSAttributedString *attributedText;
```
- In method signatures, there should be a space after the method type (-/+ symbol). There should be a space between the method segments (matching Apple's style). Always include a keyword and be descriptive with the word before the argument which describes the argument.
```objc
@interface SomeClass
- (instancetype)initWithWidth:(CGFloat)width height:(CGFloat)height;
- (void)setExampleText:(NSString *)text image:(UIImage *)image;
- (void)sendAction:(SEL)aSelector to:(id)anObject forAllCells:(BOOL)flag;
- (id)viewWithTag:(NSInteger)tag;
@end
```
- Internal methods should be prefixed with a `_`
```objc
- (void)_internalMethodWithParameter:(id)param;
```
- Method braces and other braces (if/else/switch/while etc.) always open on the same line as the statement but close on a new line.
```objc
if (foo == bar) {
  //..
} else {
  //..
}
```
- Method, `@interface` , and `@implementation` brackets on the following line
```objc
@implementation SomeClass
- (void)someMethod
{
  // Implementation
}
@end
```
- Function brackets on the same line
```objc
static void someFunction() {
  // Implementation
}
```
- Operator goes with the variable name
```objc
    NSAttributedString *attributedText = self.textNode.attributedText;
```
- Locking
  - Add a `_locked_` in front of the method name that needs to be called with a lock held
```objc
- (void)_locked_needsToBeCalledWithLock {}
```
  - Locking safety:
    - It is fine for a `_locked_` method to call other `_locked_` methods.
    - On the other hand, the following should not be done:
      - Calling normal, unlocked methods inside a `_locked_` method
      - Calling subclass hooks that are meant to be overridden by developers inside a `_locked_` method.
  - Subclass hooks
    - that are meant to be overwritten by users should not be called with a lock held.
    - that are used internally the same conventions as above apply.
- There are multiple ways to acquire a lock:
  1. Explicitly call `.lock()` and `.unlock()` :
```objc
- (void)setContentSpacing:(CGFloat)contentSpacing
{
  __instanceLock__.lock();
  BOOL needsUpdate = (contentSpacing != _contentSpacing);
  if (needsUpdate) {
    _contentSpacing = contentSpacing;
  }
  __instanceLock__.unlock();

  if (needsUpdate) {
    [self setNeedsLayout];
  }
}

- (CGFloat)contentSpacing
{
  CGFloat contentSpacing = 0.0;
  __instanceLock__.lock();
  contentSpacing = _contentSpacing;
  __instanceLock__.unlock();
  return contentSpacing;
}
```
  2. Create an `ASDN::MutexLocker` :
```objc
- (void)setContentSpacing:(CGFloat)contentSpacing
{
  {
    ASDN::MutexLocker l(__instanceLock__);
    if (contentSpacing == _contentSpacing) {
      return;
    }

    _contentSpacing = contentSpacing;
  }

  [self setNeedsLayout];
}

- (CGFloat)contentSpacing
{
  ASDN::MutexLocker l(__instanceLock__);
  return _contentSpacing;
}
```
- Nullability
  - The adoption of annotations is straightforward. The standard we adopt is using the `NS_ASSUME_NONNULL_BEGIN` and `NS_ASSUME_NONNULL_END` on all headers. Then indicate nullability for the pointers that can be so.
  - There is mostly no sense using nullability annotations outside of interface declarations.
```objc
// Properties
@property(nonatomic, strong, nullable) NSNumber *status

// Methods
- (nullable NSNumber *)doSomethingWithString:(nullable NSString *)str;

// Functions
NSString * _Nullable ASStringWithQuotesIfMultiword(NSString * _Nullable string);

// Typedefs
typedef void (^RemoteCallback)(id _Nullable result, NSError * _Nullable error);

// Block as parameter
- (void)reloadDataWithCompletion:(void (^ _Nullable)())completion;

// Block as parameter with parameter and return value
- (void)convertObject:(id _Nonnull (^ _Nullable)(id _Nullable input))handler;

// More complex pointer types
- (void)allElementsForScrolling:(ASScrollDirection)scrollDirection rangeMode:(ASLayoutRangeMode)rangeMode displaySet:(NSSet<ASCollectionElement *> *__autoreleasing  _Nullable *)displaySet preloadSet:(NSSet<ASCollectionElement *> *__autoreleasing  _Nullable *)preloadSet map:(ASElementMap *)map;
```

# Contributor License Agreement (CLA)

Please sign our Contributor License Agreement (CLA) before sending pull requests. For any code changes to be accepted, the CLA must be signed.

Complete your CLA [here](https://cla-assistant.io/TextureGroup/Texture)

# License

By contributing to Texture, you agree that your contributions will be licensed under its Apache 2 license.
