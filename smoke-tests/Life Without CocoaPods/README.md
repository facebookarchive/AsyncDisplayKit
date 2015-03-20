# "Life Without CocoaPods"

This is a very simple pseudo-"integration test" project that links against
AsyncDisplayKit manually, rather than using CocoaPods.  If it fails to compile,
Travis CI builds will fail.  To escape from such dire straits:

* If you've added a new class intended for public use, make sure you added its
  header to the "Public" group of the "Headers" build phase in the
  AsyncDisplayKit target.  Note that this smoke test will only fail if you
  remembered to add your new file to the umbrella helper.

* If you added a new framework dependency (like AssetsLibrary or Photos), add
  it to this project's Link Binary With Libraries build phase and update the
  project README (both README.md and docs/index.md).
