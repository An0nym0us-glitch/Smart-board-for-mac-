cmake_minimum_required(VERSION 3.16)

# macOS: the oldest release the app bundle runs on (Qt 5.15 supports 10.13 and later). Must be
# set before project(). Builds against libraries made for a newer macOS (e.g. Homebrew's Qt)
# should pass that version instead, e.g. -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0.
if(CMAKE_HOST_APPLE AND NOT CMAKE_OSX_DEPLOYMENT_TARGET)  # APPLE is only defined after project()
    set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "Minimum macOS version")
endif()

# The single source of the version: the app's About text, ClassBoard.exe's file properties,
# the macOS bundle's Info.plist and the installer names (ClassBoard-Setup-<version>-x64.exe,
# ClassBoard-<version>-macOS-<arch>.dmg) all come from here. A release is
# tagged v<version>; the release workflow refuses a tag that does not match.
project(ClassBoard
    VERSION 0.3.1
    DESCRIPTION "Digital classroom whiteboard for interactive displays"
    HOMEPAGE_URL "https://github.com/An0nym0us-glitch/Smart-board22"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

option(CLASSBOARD_BUILD_TESTS "Build unit tests" ON)
option(CLASSBOARD_DEPLOY_QT "Run windeployqt / macdeployqt after building (Windows / macOS)" OFF)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Gui Widgets Svg)
find_package(Qt5 5.15 QUIET OPTIONAL_COMPONENTS Pdf)

add_subdirectory(src)

if(CLASSBOARD_BUILD_TESTS)
    find_package(Qt5 5.15 REQUIRED COMPONENTS Test)
    enable_testing()
    add_subdirectory(tests)
endif()

include(cmake/Packaging.cmake)
