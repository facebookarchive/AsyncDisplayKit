This project is supposed to test that the `AsyncDisplayKit.framework` built by Carthage from the master branch can be imported as a module without causing any warnings and errors.

Steps to verify:

- Run `carthage update --platform iOS`
- Build `CarthageExample.xcodeproj`
- Verify that there are 0 Errors and 0 Warnings
