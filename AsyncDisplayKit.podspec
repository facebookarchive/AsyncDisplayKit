Pod::Spec.new do |spec|
  spec.name         = 'AsyncDisplayKit'
  spec.version      = '1.0beta'
  spec.license      =  { :type => 'BSD' }
  spec.homepage     = 'https://github.com/facebook/AsyncDisplayKit'
  spec.authors      = { 'Nadine Salter' => 'nadi@fb.com', 'Scott Goodson' => 'scottg@fb.com' }
  spec.summary      = 'Smooth asynchronous user interfaces for iOS apps.'
  spec.source       = { :git => 'https://github.com/facebook/AsyncDisplayKit.git', :tag => '1.0beta' }

  # these files mustn't be compiled with ARC enabled
  mrr_source_files = [
      'AsyncDisplayKit/ASDisplayNode.mm',
      'AsyncDisplayKit/ASControlNode.m',
      'AsyncDisplayKit/ASImageNode.mm',
      'AsyncDisplayKit/Details/_ASDisplayView.mm',
      'AsyncDisplayKit/Private/_ASPendingState.m',
    ]

  spec.public_header_files = [
      'AsyncDisplayKit/*.h',
      'AsyncDisplayKit/Details/**/*.h',
      'Base/*.h'
  ]

  spec.source_files = ['AsyncDisplayKit/**/*.{h,m,mm}', 'Base/*.{h,m}']
  spec.exclude_files = mrr_source_files

  spec.requires_arc = true
  spec.subspec 'no-arc' do |mrr|
    mrr.requires_arc = false
    mrr.source_files = mrr_source_files
  end

  spec.social_media_url = 'https://twitter.com/fbOpenSource'
  spec.library = 'c++'
  spec.xcconfig = {
       'CLANG_CXX_LANGUAGE_STANDARD' => 'c++11',
       'CLANG_CXX_LIBRARY' => 'libc++'
  }

  spec.ios.deployment_target = '7.0'
end
