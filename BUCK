#####################################
# Defines
#####################################
COMMON_PREPROCESSOR_FLAGS = [
  '-fobjc-arc',
  '-DDEBUG=1',
]

COMMON_LANG_PREPROCESSOR_FLAGS = {
  'C': ['-std=gnu99'],
  'CXX': ['-std=c++11', '-stdlib=libc++'],
  'OBJCXX': ['-std=c++11', '-stdlib=libc++'],
}

COMMON_LINKER_FLAGS = ['-ObjC++']

ASYNCDISPLAYKIT_EXPORTED_HEADERS = glob([
  'Source/*.h',
  'Source/Details/**/*.h',
  'Source/Layout/*.h',
  'Source/Base/*.h',
  'Source/Debug/AsyncDisplayKit+Debug.h',
  # Most TextKit components are not public because the C++ content
  # in the headers will cause build errors when using
  # `use_frameworks!` on 0.39.0 & Swift 2.1.
  # See https://github.com/facebook/AsyncDisplayKit/issues/1153
  'Source/TextKit/ASTextNodeTypes.h',
  'Source/TextKit/ASTextKitComponents.h'
])

ASYNCDISPLAYKIT_PRIVATE_HEADERS = glob([
    'Source/**/*.h'
  ],
  excludes = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
)

def asyncdisplaykit_library(
    name,
    additional_preprocessor_flags = [],
    deps = [],
    additional_frameworks = []):

  apple_library(
    name = name,
    prefix_header = 'Source/AsyncDisplayKit-Prefix.pch',
    header_path_prefix = 'AsyncDisplayKit',
    exported_headers = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
    headers = ASYNCDISPLAYKIT_PRIVATE_HEADERS,
    srcs = glob([
      'Source/**/*.m',
      'Source/**/*.mm',
      'Source/Base/*.m'
    ]),
    preprocessor_flags = COMMON_PREPROCESSOR_FLAGS + additional_preprocessor_flags,
    lang_preprocessor_flags = COMMON_LANG_PREPROCESSOR_FLAGS,
    linker_flags = COMMON_LINKER_FLAGS + [
      '-weak_framework',
      'Photos',
      '-weak_framework',
      'MapKit',
    ],
    deps = deps,
    frameworks = [
      '$SDKROOT/System/Library/Frameworks/Foundation.framework',
      '$SDKROOT/System/Library/Frameworks/UIKit.framework',

      '$SDKROOT/System/Library/Frameworks/QuartzCore.framework',
      '$SDKROOT/System/Library/Frameworks/CoreMedia.framework',
      '$SDKROOT/System/Library/Frameworks/CoreText.framework',
      '$SDKROOT/System/Library/Frameworks/CoreGraphics.framework',
      '$SDKROOT/System/Library/Frameworks/CoreLocation.framework',
      '$SDKROOT/System/Library/Frameworks/AVFoundation.framework',

      # TODO somehow AssetsLibrary can't be weak_framework
      '$SDKROOT/System/Library/Frameworks/AssetsLibrary.framework',
    ] + additional_frameworks,
    visibility = ['PUBLIC'],
  )

#####################################
# AsyncDisplayKit targets
#####################################
asyncdisplaykit_library(
  name = 'AsyncDisplayKit-Core',
)

# (Default) AsyncDisplayKit and AsyncDisplayKit-PINRemoteImage targets are basically the same library with different names
for name in ['AsyncDisplayKit', 'AsyncDisplayKit-PINRemoteImage']:
  asyncdisplaykit_library(
    name = name,
    deps = [
      '//Pods/PINRemoteImage:PINRemoteImage-PINCache',
    ],
    additional_frameworks = [
      '$SDKROOT/System/Library/Frameworks/MobileCoreServices.framework',
    ]
  )

#####################################
# Test Host
# TODO: Split to smaller BUCK files and parse in parallel
#####################################
apple_resource(		
  name = 'TestHostResources',		
  files = ['Tests/TestHost/Default-568h@2x.png'],		
  dirs = [],		
 )

apple_bundle(
  name = 'TestHost',
  binary = ':TestHostBinary',
  extension = 'app',
  info_plist = 'Tests/TestHost/Info.plist',
  info_plist_substitutions = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.facebook.AsyncDisplayKitTestHost',
  },
  tests = [':Tests'],
)

apple_binary(
  name = 'TestHostBinary',
  headers = glob(['Tests/TestHost/*.h']),
  srcs = glob(['Tests/TestHost/*.m']),
  lang_preprocessor_flags = COMMON_LANG_PREPROCESSOR_FLAGS,
  linker_flags = COMMON_LINKER_FLAGS,
  deps = [
    ':TestHostResources',
    ':AsyncDisplayKit-Core',
  ],
  frameworks = [
    '$SDKROOT/System/Library/Frameworks/Photos.framework',
    '$SDKROOT/System/Library/Frameworks/MapKit.framework',
  ],
)

apple_package(
  name = 'TestHostPackage',
  bundle = ':TestHost',
)

#####################################
# Tests
#####################################
apple_resource(
  name = 'TestsResources',
  files = ['Tests/en.lproj/InfoPlist.strings'],
  dirs = ['Tests/TestResources'],
)

apple_test(
  name = 'Tests',
  test_host_app = ':TestHost',
  info_plist = 'Tests/AsyncDisplayKitTests-Info.plist',
  info_plist_substitutions = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.facebook.AsyncDisplayKitTests',
  },
  prefix_header = 'Tests/AsyncDisplayKitTests-Prefix.pch',
  header_path_prefix = 'AsyncDisplayKit',
  # Expose all ASDK headers to tests
  headers = ASYNCDISPLAYKIT_EXPORTED_HEADERS + ASYNCDISPLAYKIT_PRIVATE_HEADERS + glob(['Tests/*.h']),
  srcs = glob([
      'Tests/*.m',
      'Tests/*.mm'
    ],
    # ASTextNodePerformanceTests are excluded (#2173)
    excludes = ['Tests/ASTextNodePerformanceTests.m*']
  ),
  snapshot_reference_images_path='Tests/ReferenceImages',
  preprocessor_flags = COMMON_PREPROCESSOR_FLAGS + [
    '-Wno-implicit-function-declaration',
    '-Wno-deprecated-declarations',
  ],
  lang_preprocessor_flags = COMMON_LANG_PREPROCESSOR_FLAGS,
  linker_flags = COMMON_LINKER_FLAGS,
  deps = [
    ':TestsResources',
    '//Pods/OCMock:OCMock',
    '//Pods/FBSnapshotTestCase:FBSnapshotTestCase',
    '//Pods/JGMethodSwizzler:JGMethodSwizzler',
  ],
  frameworks = [
    '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    '$SDKROOT/System/Library/Frameworks/UIKit.framework',

    '$SDKROOT/System/Library/Frameworks/CoreMedia.framework',
    '$SDKROOT/System/Library/Frameworks/CoreText.framework',
    '$SDKROOT/System/Library/Frameworks/CoreGraphics.framework',
    '$SDKROOT/System/Library/Frameworks/AVFoundation.framework',

    '$PLATFORM_DIR/Developer/Library/Frameworks/XCTest.framework',
  ],
)
