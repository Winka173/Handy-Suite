Pod::Spec.new do |s|
  s.name = 'handy_capture'
  s.version = '0.1.0'
  s.summary = 'Local ReplayKit and AVFoundation capture processing.'
  s.description = 'Flutter adapter for the existing Handy Snap native capture engine.'
  s.homepage = 'https://github.com/handy-suite/handy-suite'
  s.license = { :type => 'Proprietary' }
  s.author = 'Handy Suite'
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.4'
  s.swift_version = '5.9'
  s.static_framework = true
  s.resource_bundles = { 'HandyCapturePrivacy' => ['PrivacyInfo.xcprivacy'] }
  s.frameworks = 'ReplayKit', 'AVFoundation', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
