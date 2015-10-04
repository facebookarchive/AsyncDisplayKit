# "Framework"

This is a very simple pseudo-"integration test" project that links against
AsyncDisplayKit as a dynamic framework, for Swift/Carthage users.  

If it fails to compile, Travis CI builds will fail.  To escape from such dire straits:

* If you've added a new class intended for public use, make sure you added its
  header to the "Public" group of the "Headers" build phase in the
  AsyncDisplayKit-iOS framework target.  Note that this smoke test will only fail
  if you remembered to add your new file to the umbrella helper.
