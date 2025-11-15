cmake_minimum_required(VERSION 3.16)

project(oiia-goose LANGUAGES CXX)

file(GLOB VERILOG_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/hdl/*.v)

# No `oiia-goose` target is created in this CMakeLists.  Set the C++
# standard and common compile flags globally instead of applying them
# to a non-existent target.
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -W -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-sign-compare)
    # Add release-only flags to the release flags variable (applies when
    # building with a Release config).
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -march=native -flto")
endif()

add_executable(make_bitmaps tools/make_bitmaps.cpp)
target_compile_features(make_bitmaps PRIVATE cxx_std_20)
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(make_bitmaps PRIVATE -Wall -W -Wextra -Wpedantic)
endif()

add_executable(make_music tools/make_music.cpp)
target_compile_features(make_music PRIVATE cxx_std_20)
if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(make_music PRIVATE -Wall -W -Wextra -Wpedantic)
endif()