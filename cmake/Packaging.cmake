# Installation and packaging (CPack). On Windows this produces a ZIP and, when NSIS is
# installed, an installer that also registers the .classboard file type. On macOS it produces
# a drag-to-Applications disk image (ClassBoard-<version>-macOS-<arch>.dmg) holding a
# self-contained ClassBoard.app.
install(FILES
    "${PROJECT_SOURCE_DIR}/README.md"
    "${PROJECT_SOURCE_DIR}/LICENSE"
    "${PROJECT_SOURCE_DIR}/THIRD_PARTY_NOTICES.md"
    "${PROJECT_SOURCE_DIR}/docs/ClassBoard-User-Guide.pdf"
    DESTINATION doc)
# Full texts of the licences named in THIRD_PARTY_NOTICES.md (Qt: LGPL 3, Poppler: GPL).
install(DIRECTORY "${PROJECT_SOURCE_DIR}/licenses/" DESTINATION doc/licenses)

# Optional: ship Poppler's command line tools (pdftoppm + DLLs) for offline PDF import.
set(CLASSBOARD_POPPLER_DIR "" CACHE PATH "Folder containing pdftoppm and its libraries, installed as bin/poppler/bin")
if(CLASSBOARD_POPPLER_DIR AND NOT APPLE)
    install(DIRECTORY "${CLASSBOARD_POPPLER_DIR}/" DESTINATION bin/poppler/bin)
endif()

set(CPACK_PACKAGE_NAME "ClassBoard")
set(CPACK_PACKAGE_VENDOR "ClassBoard contributors")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "ClassBoard")
if(NOT APPLE)
    # On macOS this would turn into a licence agreement that blocks opening the disk image
    # (and mounting it from scripts); LICENSE is in the image's doc folder instead.
    set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")
endif()
set(CPACK_PACKAGE_EXECUTABLES "ClassBoard" "ClassBoard")

if(WIN32)
    set(CPACK_GENERATOR "ZIP;NSIS")
    set(CPACK_NSIS_DISPLAY_NAME "ClassBoard ${PROJECT_VERSION}")
    set(CPACK_NSIS_MUI_ICON "${PROJECT_SOURCE_DIR}/resources/app/classboard.ico")
    set(CPACK_NSIS_INSTALLED_ICON_NAME "bin\\\\ClassBoard.exe")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS "
        WriteRegStr HKCR '.classboard' '' 'ClassBoard.Lesson'
        WriteRegStr HKCR 'ClassBoard.Lesson' '' 'ClassBoard lesson'
        WriteRegStr HKCR 'ClassBoard.Lesson\\\\DefaultIcon' '' '$INSTDIR\\\\bin\\\\ClassBoard.exe,0'
        WriteRegStr HKCR 'ClassBoard.Lesson\\\\shell\\\\open\\\\command' '' '\\\"$INSTDIR\\\\bin\\\\ClassBoard.exe\\\" \\\"%1\\\"'
    ")
    set(CPACK_NSIS_EXTRA_UNINSTALL_COMMANDS "
        DeleteRegKey HKCR '.classboard'
        DeleteRegKey HKCR 'ClassBoard.Lesson'
    ")
    # Qt runtime: deploy with windeployqt into the install tree.
    install(CODE "
        get_filename_component(_qtbin \"${Qt5_DIR}/../../../bin\" ABSOLUTE)
        find_program(_windeployqt windeployqt HINTS \"\${_qtbin}\")
        if(_windeployqt)
            execute_process(COMMAND \"\${_windeployqt}\" --no-translations --no-system-d3d-compiler --no-opengl-sw
                                    \"\${CMAKE_INSTALL_PREFIX}/bin/ClassBoard.exe\")
        endif()
    ")
elseif(APPLE)
    set(CPACK_GENERATOR "DragNDrop")
    set(CPACK_DMG_VOLUME_NAME "ClassBoard ${PROJECT_VERSION}")
    set(CPACK_DMG_FORMAT "UDZO")
    if(CMAKE_OSX_ARCHITECTURES)
        string(REPLACE ";" "-" _arch "${CMAKE_OSX_ARCHITECTURES}")
    else()
        set(_arch "${CMAKE_SYSTEM_PROCESSOR}")
    endif()
    set(CPACK_PACKAGE_FILE_NAME "ClassBoard-${PROJECT_VERSION}-macOS-${_arch}")

    # Optional: Poppler's pdftoppm for PDF import without Qt PDF (e.g. Homebrew's
    # /opt/homebrew/bin/pdftoppm). It is copied into ClassBoard.app/Contents/MacOS and
    # macdeployqt bundles the libraries it needs.
    set(CLASSBOARD_PDFTOPPM "" CACHE FILEPATH "pdftoppm executable to ship inside ClassBoard.app")
    if(CLASSBOARD_PDFTOPPM)
        install(PROGRAMS "${CLASSBOARD_PDFTOPPM}" DESTINATION ClassBoard.app/Contents/MacOS)
    endif()

    # Qt runtime: cmake/MacDeploy.cmake runs macdeployqt on the installed bundle, removes
    # library search paths that point outside it and signs it, ad hoc by default. A Developer
    # ID can be used instead with -DCLASSBOARD_CODESIGN_IDENTITY="Developer ID Application: ...".
    set(CLASSBOARD_CODESIGN_IDENTITY "-" CACHE STRING "codesign identity for ClassBoard.app ('-' = ad hoc)")
    get_target_property(_qmake Qt5::qmake IMPORTED_LOCATION)
    get_filename_component(_qtbin "${_qmake}" DIRECTORY)
    find_program(CLASSBOARD_MACDEPLOYQT macdeployqt HINTS "${_qtbin}" NO_DEFAULT_PATH)
    install(CODE "
        set(CLASSBOARD_MACDEPLOYQT \"${CLASSBOARD_MACDEPLOYQT}\")
        set(CLASSBOARD_CODESIGN_IDENTITY \"${CLASSBOARD_CODESIGN_IDENTITY}\")
    ")
    install(SCRIPT "${PROJECT_SOURCE_DIR}/cmake/MacDeploy.cmake")
else()
    set(CPACK_GENERATOR "TGZ")
endif()

include(CPack)
