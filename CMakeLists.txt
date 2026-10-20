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
        TemporalTableChart.qml
)

# ── Emoji font ────────────────────────────────────────────────────────────────
# Source: git submodule at third_party/noto-emoji
# License: SIL Open Font License 1.1 — free to embed in any application.
# We use the monochrome TTF (not the color WOFF2) because Qt's text engine
# handles outline fonts reliably on all platforms including WASM.
set(EMOJI_FONT "${CMAKE_SOURCE_DIR}/third_party/noto-emoji/fonts/NotoColorEmoji.ttf")

if(EXISTS "${EMOJI_FONT}")
    # Qt resource system requires relative paths — set an alias so the
    # absolute submodule path is exposed as "NotoColorEmoji.ttf" inside
    # the resource prefix /fonts/
    set_source_files_properties("${EMOJI_FONT}"
        PROPERTIES QT_RESOURCE_ALIAS "NotoColorEmoji.ttf"
    )
    qt_add_resources(appQtSpeis "appfonts"
        PREFIX "/fonts"
        FILES "${EMOJI_FONT}"
        BIG_RESOURCES
    )
    target_compile_definitions(appQtSpeis PRIVATE HAS_EMOJI_FONT)
    message(STATUS "Emoji font found: ${EMOJI_FONT}")
else()
    message(WARNING
        "Emoji font not found at ${EMOJI_FONT}\n"
        "Run: git submodule update --init --recursive")
endif()

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

# ── WebAssembly ───────────────────────────────────────────────────────────────
if(EMSCRIPTEN)
    target_compile_definitions(appQtSpeis PRIVATE QTSPEIS_WASM)

    target_link_options(appQtSpeis PRIVATE
        "SHELL:-s ALLOW_MEMORY_GROWTH=1"
        "SHELL:-s EXPORTED_RUNTIME_METHODS=[getValue]"
    )

    set_target_properties(appQtSpeis PROPERTIES
        QT_WASM_INITIAL_MEMORY "64MB"
    )
endif()

file(COPY plan.yaml schedule_week.yaml schedule_1440_minutes.yaml DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

include(GNUInstallDirs)
install(TARGETS appQtSpeis
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
