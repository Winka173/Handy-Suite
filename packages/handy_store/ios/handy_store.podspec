#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint handy_store.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'handy_store'
  s.version          = '0.1.0'
  s.summary          = 'Native verified lifetime store ownership.'
  s.description      = <<-DESC
Native verified lifetime store ownership.
                       DESC
  s.homepage         = 'https://handysuite.local'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Handy Suite'
  s.source           = { :path => '.' }
  s.source_files = 'handy_store/Sources/handy_store/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'handy_store_privacy' => ['handy_store/Sources/handy_store/PrivacyInfo.xcprivacy']}
end
