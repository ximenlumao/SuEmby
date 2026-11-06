cmake_minimum_required(VERSION 3.21)
project(SuEmby LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 6.5 REQUIRED COMPONENTS Quick Network OpenGL)
find_path(MPV_INCLUDE_DIR mpv/client.h REQUIRED)
find_library(MPV_LIBRARY NAMES mpv mpv-2 REQUIRED)
qt_add_executable(SuEmby WIN32
  src/main.cpp
  src/embyclient.cpp
  src/embyclient.h
  src/player.cpp
  src/player.h
  src/mpvvideorenderer.cpp
  src/mpvvideorenderer.h
)
set_target_properties(SuEmby PROPERTIES AUTOMOC ON)
qt_add_resources(SuEmby qml PREFIX "/" FILES qml/Main.qml)
target_include_directories(SuEmby PRIVATE ${MPV_INCLUDE_DIR})
target_link_libraries(SuEmby PRIVATE Qt6::Quick Qt6::Network Qt6::OpenGL ${MPV_LIBRARY} Crypt32)
install(TARGETS SuEmby RUNTIME DESTINATION .)
