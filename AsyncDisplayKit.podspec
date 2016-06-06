Pod::Spec.new do |spec|
  spec.name         = 'AsyncDisplayKit'
  spec.version      = '1.9.80'
  spec.license      =  { :type => 'BSD' }
  spec.homepage     = 'http://asyncdisplaykit.org'
  spec.authors      = { 'Scott Goodson' => 'scottgoodson@gmail.com', 'Ryan Nystrom' => 'rnystrom@fb.com' }
  spec.summary      = 'Smooth asynchronous user interfaces for iOS apps.'
  spec.source       = { :git => 'https://github.com/facebook/AsyncDisplayKit.git', :tag => '1.9.80' }

  spec.documentation_url = 'http://asyncdisplaykit.org/appledoc/'

  spec.frameworks = 'AssetsLibrary'
  spec.weak_frameworks = 'Photos','MapKit'
  spec.requires_arc = true

  spec.ios.deployment_target = '7.0'

  # Uncomment when fixed: issues with tvOS build for release 1.9.8
  # spec.tvos.deployment_target = '9.0'

  # Subspecs
  spec.subspec 'Core' do |core|
    core.public_header_files = [
        'AsyncDisplayKit/*.h',
        'AsyncDisplayKit/Details/**/*.h',
        'AsyncDisplayKit/Layout/*.h',
        'Base/*.h',
        'AsyncDisplayKit/TextKit/ASTextNodeTypes.h',
        'AsyncDisplayKit/TextKit/ASTextKitComponents.h'
    ]
    
    # ASDealloc2MainObject must be compiled with MRR
    core.exclude_files = [
      'AsyncDisplayKit/Private/_AS-objc-internal.h',
      'AsyncDisplayKit/Details/ASDealloc2MainObject.h',
      'AsyncDisplayKit/Details/ASDealloc2MainObject.m',
    ]
    core.source_files = [
        'AsyncDisplayKit/**/*.{h,m,mm}',
        'Base/*.{h,m}',
      
        # Most TextKit components are not public because the C++ content
        # in the headers will cause build errors when using
        # `use_frameworks!` on 0.39.0 & Swift 2.1.
        # See https://github.com/facebook/AsyncDisplayKit/issues/1153
        'AsyncDisplayKit/TextKit/*.h',
    ]
    core.dependency  'AsyncDisplayKit/ASDealloc2MainObject'
  end
  
  spec.subspec 'ASDealloc2MainObject' do |mrr|
    mrr.requires_arc = false
    mrr.source_files = [
      'AsyncDisplayKit/Private/_AS-objc-internal.h',
      'AsyncDisplayKit/Details/ASDealloc2MainObject.h',
      'AsyncDisplayKit/Details/ASDealloc2MainObject.m',
    ]
  end
  
  spec.subspec 'PINRemoteImage' do |pin|
      pin.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) PIN_REMOTE_IMAGE=1' }
      pin.dependency 'PINRemoteImage/iOS', '>= 3.0.0-beta.2'
      pin.dependency 'AsyncDisplayKit/Core'
  end
  
  # Include optional PINRemoteImage module
  spec.default_subspec = 'PINRemoteImage'

  spec.social_media_url = 'https://twitter.com/fbOpenSource'
  spec.library = 'c++'
  spec.pod_target_xcconfig = {
       'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
       'CLANG_CXX_LIBRARY' => 'libc++'
  }

end
