#####################################
# Defines
#####################################
COMMON_PREPROCESSOR_FLAGS = ['-fobjc-arc']

COMMON_LANG_PREPROCESSOR_FLAGS = {
  'C': ['-std=gnu99'],
  'CXX': ['-std=gnu++11', '-stdlib=libc++'],
}

FLANIMATEDIMAGE_HEADER_FILES = ['Pod/Classes/Image Categories/FLAnimatedImageView+PINRemoteImage.h']
FLANIMATEDIMAGE_SOURCE_FILES = ['Pod/Classes/Image Categories/FLAnimatedImageView+PINRemoteImage.m']

PINCACHE_HEADER_FILES = glob(['Pod/Classes/PINCache/**/*.h'])
PINCACHE_SOURCE_FILES = glob(['Pod/Classes/PINCache/**/*.m'])

#####################################
# PINRemoteImage core targets
#####################################
apple_library(
  name = 'PINRemoteImage-Core',
  header_path_prefix = 'PINRemoteImage',
  exported_headers = glob([
      'Pod/Classes/**/*.h',
    ],
    excludes = FLANIMATEDIMAGE_HEADER_FILES + PINCACHE_HEADER_FILES
  ),
  srcs = glob([
      'Pod/Classes/**/*.m',
    ],
    excludes = FLANIMATEDIMAGE_SOURCE_FILES + PINCACHE_SOURCE_FILES
  ),
  preprocessor_flags = COMMON_PREPROCESSOR_FLAGS + [
    '-DPIN_TARGET_IOS=(TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR || TARGET_OS_TV)',
    '-DPIN_TARGET_MAC=(TARGET_OS_MAC)',
  ],
  lang_preprocessor_flags = COMMON_LANG_PREPROCESSOR_FLAGS,
  linker_flags = [
    '-weak_framework',
    'UIKit',
    '-weak_framework',
    'MobileCoreServices',
    '-weak_framework',
    'Cocoa',
    '-weak_framework',
    'CoreServices',
  ],
  frameworks = [
    '$SDKROOT/System/Library/Frameworks/ImageIO.framework',
    '$SDKROOT/System/Library/Frameworks/Accelerate.framework',
  ],
  visibility = ['PUBLIC'],
)

apple_library(
  name = 'PINRemoteImage',
  deps = [
    ':PINRemoteImage-FLAnimatedImage',
    ':PINRemoteImage-PINCache'
  ],
  visibility = ['PUBLIC'],
)

#####################################
# Other PINRemoteImage targets
#####################################
apple_library(
  name = 'PINRemoteImage-FLAnimatedImage',
  header_path_prefix = 'PINRemoteImage',
  exported_headers = FLANIMATEDIMAGE_HEADER_FILES,
  srcs = FLANIMATEDIMAGE_SOURCE_FILES,
  preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
  deps = [
    ':PINRemoteImage-Core',
    '//Pods/FLAnimatedImage:FLAnimatedImage'
  ],
  visibility = ['PUBLIC'],
)

apple_library(
  name = 'PINRemoteImage-PINCache',
  header_path_prefix = 'PINRemoteImage',
  exported_headers = PINCACHE_HEADER_FILES,
  srcs = PINCACHE_SOURCE_FILES,
  preprocessor_flags = COMMON_PREPROCESSOR_FLAGS,
  deps = [
    ':PINRemoteImage-Core',
    '//Pods/PINCache:PINCache'
  ],
  visibility = ['PUBLIC'],
)

#TODO WebP variants
