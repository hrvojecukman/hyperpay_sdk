Pod::Spec.new do |s|
  s.name             = 'hyperpay_sdk'
  s.version          = '7.4.0'
  s.summary          = 'Flutter plugin wrapping HyperPay (OPPWA) Mobile SDK v7.4.0.'
  s.description      = <<-DESC
Flutter plugin for integrating HyperPay (OPPWA) Mobile SDK v7.4.0 on iOS.
Supports ReadyUI, CustomUI, Apple Pay, tokenization, and 3DS2.
                       DESC
  s.homepage         = 'https://github.com/hrvojecukman/hyperpay_sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hrvoje Cukman' => 'hrvojecukman@gmail.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'

  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  s.dependency 'Flutter'

  # HyperPay OPPWA SDK (user must place these in ios/Frameworks/)
  s.preserve_paths   = 'Frameworks/**/*'
  s.vendored_frameworks = [
    'Frameworks/OPPWAMobile.xcframework',
    'Frameworks/ipworks3ds_sdk_deploy_9373.xcframework'
  ]

  # System frameworks required by the SDK
  s.frameworks = [
    'SafariServices',
    'PassKit',
    'AuthenticationServices',
    'Security',
    'WebKit'
  ]

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) "$(PODS_ROOT)/../.symlinks/plugins/hyperpay_sdk/ios/Frameworks"',
    'OTHER_LDFLAGS' => '$(inherited) -framework OPPWAMobile',
  }

  # Flutter.framework does not contain a i386 slice.
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  # Ensure this is built as a static framework (OPPWA SDK requires it)
  s.static_framework = true
end
