cmake_minimum_required(VERSION 3.22.1)

project(iosmacs_android_runtime LANGUAGES CXX)

add_library(
  iosmacs_android_runtime
  SHARED
  iosmacs_android_runtime.cpp
)

target_compile_features(iosmacs_android_runtime PRIVATE cxx_std_17)
