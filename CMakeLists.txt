cmake_minimum_required(VERSION 3.16)

project(MapDataOverlay VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick QuickControls2 Positioning Location ShaderTools Sql)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(appMapDataOverlay
    main.cpp
    climatedatamodel.h
    climatedatamodel.cpp
)

qt_add_qml_module(appMapDataOverlay
    URI MapDataOverlay
    VERSION 1.0
    QML_FILES
        Main.qml
        MapDataOverlay.qml
)

# Compile shaders using Qt Shader Tools
qt_add_shaders(appMapDataOverlay "shaders"
    BATCHABLE
    PRECOMPILE
    OPTIMIZED
    PREFIX
        "/"
    FILES
        shaders/overlay.vert
        shaders/overlay.frag
)

set_target_properties(appMapDataOverlay PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.mapdataoverlay
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appMapDataOverlay
    PRIVATE
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Positioning
        Qt6::Location
        Qt6::Sql
)

install(TARGETS appMapDataOverlay
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
