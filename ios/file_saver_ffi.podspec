#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint file_saver_ffi.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'file_saver_ffi'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for saving files to device storage using FFI and JNI'
  s.description      = <<-DESC
A Flutter plugin for saving files to device storage using FFI and JNI
                       DESC
  s.homepage         = 'https://github.com/vanvixi/file_saver_ffi.flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vanvixi' => 'vanvixi.dev@gmail.com' }

  # This will ensure the source files in Classes/ are included in the native
  # builds of apps using this FFI plugin.
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.{h,c,swift}'
  s.public_header_files = 'Classes/**/include/*.h', 'Classes/**/file_saver_ffi.h'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.ios.deployment_target = '13.0'

  # Preserve the module map for DartApiDl module
  s.preserve_paths = 'Classes/FileSaver/FFI/include/module.modulemap'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)/Classes/FileSaver/FFI/include',
    'OTHER_CFLAGS' => '-I$(PODS_TARGET_SRCROOT)/Classes/FileSaver/FFI/include'
  }
  s.swift_version = '5.0'
end
