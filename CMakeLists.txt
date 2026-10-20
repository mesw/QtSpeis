cmake_minimum_required(VERSION 3.16)

project(QtSpeis VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appQtSpeis
    main.cpp
)

qt_add_qml_module(appQtSpeis
    URI QtSpeis
    SOURCES
        dayplanmodel.h
        dayplanmodel.cpp
        tvprogramfetcher.h
        tvprogramfetcher.cpp
    QML_FILES
        Main.qml
        TemporalPieChart.qml
        TemporalSpiralChart.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appQtSpeis PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appQtSpeis
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appQtSpeis
    PRIVATE Qt6::Quick Qt6::Network
)

file(COPY plan.yaml schedule_week.yaml schedule_1440_minutes.yaml DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

include(GNUInstallDirs)
install(TARGETS appQtSpeis
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
