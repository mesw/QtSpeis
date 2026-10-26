cmake_minimum_required(VERSION 3.16)

project(QtSpeis VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network Sql QuickControls2)

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
        fooddatabase.h
        fooddatabase.cpp
        openfoodfactsfetcher.h
        openfoodfactsfetcher.cpp
        mealplanmanager.h
        mealplanmanager.cpp
        gamelevelmanager.h
        gamelevelmanager.cpp
        languagemanager.h
        languagemanager.cpp
        savegamemanager.h
        savegamemanager.cpp
        recipemanager.h
        recipemanager.cpp
    QML_FILES
        Main.qml
        TemporalPieChart.qml
        TemporalSpiralChart.qml
        TemporalTableChart.qml
        CozyShoppingList.qml
        GoalSummaryCard.qml
        BarcodeLookupDialog.qml
        LevelSelectView.qml
        EvaluationResultDialog.qml
        SavegameDialog.qml
        UserProfileDialog.qml
        WorkoutDialog.qml
        RecipeLibraryDialog.qml
        WorkoutLibraryDialog.qml
        AboutLegalDialog.qml
        IngredientExplorerDialog.qml
        OnboardingDialog.qml
    RESOURCES
        qtquickcontrols2.conf
        all_32_recipes_detailed.json
)

# ── Translations ────────────────────────────────────────────────────────────
set(SPEIS_QM "${CMAKE_CURRENT_SOURCE_DIR}/translations/qtspeis_de.qm")
if(EXISTS "${SPEIS_QM}")
    set_source_files_properties("${SPEIS_QM}"
        PROPERTIES QT_RESOURCE_ALIAS "translations/qtspeis_de.qm"
    )
    qt_add_resources(appQtSpeis "speis_i18n_res"
        PREFIX "/"
        FILES "${SPEIS_QM}"
    )
    message(STATUS "Embedded qtspeis_de.qm into resources: ${SPEIS_QM}")
endif()

find_program(SPEIS_LRELEASE lrelease HINTS "C:/Qt/6.8.3/mingw_64/bin")
if(SPEIS_LRELEASE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/translations/qtspeis_de.ts")
    add_custom_target(speis_update_translations
        COMMAND ${SPEIS_LRELEASE} "${CMAKE_CURRENT_SOURCE_DIR}/translations/qtspeis_de.ts" -qm "${CMAKE_CURRENT_SOURCE_DIR}/translations/qtspeis_de.qm"
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        COMMENT "Compiling Qt Linguist translations/qtspeis_de.ts to translations/qtspeis_de.qm"
    )
    add_dependencies(appQtSpeis speis_update_translations)
endif()

# ── Speis SQLite Database ───────────────────────────────────────────────────
set(SPEIS_DB "${CMAKE_CURRENT_SOURCE_DIR}/speis.db")
if(EXISTS "${SPEIS_DB}")
    set_source_files_properties("${SPEIS_DB}"
        PROPERTIES QT_RESOURCE_ALIAS "speis.db"
    )
    qt_add_resources(appQtSpeis "speis_db_res"
        PREFIX "/"
        FILES "${SPEIS_DB}"
        BIG_RESOURCES
    )
    message(STATUS "Embedded speis.db into resources: ${SPEIS_DB}")
endif()

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
    PRIVATE Qt6::Quick Qt6::Network Qt6::Sql Qt6::QuickControls2
)

# ── WebAssembly ───────────────────────────────────────────────────────────────
if(EMSCRIPTEN)
    target_compile_definitions(appQtSpeis PRIVATE QTSPEIS_WASM)

    target_link_options(appQtSpeis PRIVATE
        "SHELL:-s ALLOW_MEMORY_GROWTH=1"
    )

    set_target_properties(appQtSpeis PROPERTIES
        QT_WASM_INITIAL_MEMORY "64MB"
    )
endif()

file(COPY speis.db plan.yaml schedule_week.yaml schedule_1440_minutes.yaml DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

include(GNUInstallDirs)
install(TARGETS appQtSpeis
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
