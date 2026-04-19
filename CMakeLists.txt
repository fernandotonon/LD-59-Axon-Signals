cmake_minimum_required(VERSION 3.16)
project(AxonSignals LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 5.12 QUIET COMPONENTS Core Quick QuickControls2 QuickLayouts Multimedia)
if (Qt5_FOUND)
    set(QT_VER 5)
else()
    find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 QuickLayouts Quick3D Multimedia)
    set(QT_VER 6)
endif()

if(QT_VER EQUAL 6)
  qt_add_executable(AxonSignals
    src/main.cpp
    qml/qml.qrc
  )
else()
  add_executable(AxonSignals
    src/main.cpp
    qml/qml.qrc
  )
endif()

target_link_libraries(AxonSignals
  PRIVATE
    Qt${QT_VER}::Core
    Qt${QT_VER}::Quick
    Qt${QT_VER}::QuickControls2
    Qt${QT_VER}::QuickLayouts
    Qt${QT_VER}::Multimedia
)

if(QT_VER EQUAL 6)
  target_link_libraries(AxonSignals PRIVATE Qt6::Quick3D)
endif()

if(QT_VER EQUAL 6)
  qt_import_qml_plugins(AxonSignals)
endif()
