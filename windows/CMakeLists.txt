cmake_minimum_required(VERSION 3.14)
project(file_saver_ffi_library VERSION 0.0.1 LANGUAGES CXX)

# No native C++ plugin code — Windows is implemented at the Dart FFI layer.
# (path_provider_windows uses SHGetKnownFolderPath via dart:ffi; folder picker uses COM via dart:ffi)
# This file exists only to satisfy Flutter's cmake plugin build system.

add_library(file_saver_ffi_plugin STATIC
  file_saver_ffi_plugin_c_api.cc
)
set_target_properties(file_saver_ffi_plugin PROPERTIES
  PUBLIC_HEADER include/file_saver_ffi/file_saver_ffi_plugin_c_api.h
)
target_include_directories(file_saver_ffi_plugin PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
