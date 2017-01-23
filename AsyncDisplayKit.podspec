Pod::Spec.new do |spec|
  spec.name         = 'AsyncDisplayKit'
  spec.version      = '2.0.2'
  spec.license      =  { :type => 'BSD' }
  spec.homepage     = 'http://asyncdisplaykit.org'
  spec.authors      = { 'Scott Goodson' => 'scottgoodson@gmail.com' }
  spec.summary      = 'Smooth asynchronous user interfaces for iOS apps.'
  spec.source       = { :git => 'https://github.com/facebook/AsyncDisplayKit.git', :tag => spec.version.to_s }

  spec.documentation_url = 'http://asyncdisplaykit.org/appledoc/'

  spec.frameworks = 'AssetsLibrary'
  spec.weak_frameworks = 'Photos','MapKit'
  spec.requires_arc = true

  spec.ios.deployment_target = '7.0'

  # Uncomment when fixed: issues with tvOS build for release 2.0
  # spec.tvos.deployment_target = '9.0'

  # Subspecs
  spec.subspec 'Core' do |core|
    core.public_header_files = [
        'AsyncDisplayKit/*.h',
        'AsyncDisplayKit/Details/**/*.h',
        'AsyncDisplayKit/Layout/*.h',
        'Base/*.h',
        'AsyncDisplayKit/Debug/ASLayoutElementInspectorNode.h',
        'AsyncDisplayKit/TextKit/ASTextNodeTypes.h',
        'AsyncDisplayKit/TextKit/ASTextKitComponents.h'
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
  end
  
  spec.subspec 'PINRemoteImage' do |pin|
      pin.xcconfig = { 'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) PIN_REMOTE_IMAGE=1' }
      pin.dependency 'PINRemoteImage/iOS', '= 3.0.0-beta.7'
      pin.dependency 'PINRemoteImage/PINCache'
      pin.dependency 'AsyncDisplayKit/Core'
  end
  
  # Include optional PINRemoteImage module
  spec.default_subspec = 'PINRemoteImage'

  spec.social_media_url = 'https://twitter.com/AsyncDisplayKit'
  spec.library = 'c++'
  spec.pod_target_xcconfig = {
       'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
       'CLANG_CXX_LIBRARY' => 'libc++'
  }

end
