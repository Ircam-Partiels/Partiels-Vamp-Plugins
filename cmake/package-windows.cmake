# The generation of the Windows packages: the plugins are installed in
# "C:\Program Files\Vamp Plugins" with Inno Setup (with a component per
# plugin, which allows the selection at the installation).
message(STATUS "Preparing Windows package")

set(OS_NAME "Windows")
set(JOB_NAME "Build::Windows")
set(WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Windows")
file(REMOVE_RECURSE "${WORKING_DIRECTORY}")
file(MAKE_DIRECTORY "${WORKING_DIRECTORY}")
set(TEMP_DIRECTORY "${WORKING_DIRECTORY}/Temp")

pvp_write_about_header("${WORKING_DIRECTORY}")

function(pvp_finalize_plugin plugin_name plugin_version)
  pvp_append_about(${plugin_name} ${plugin_version} "${WORKING_DIRECTORY}/About.txt")
  pvp_extract_bundle("${plugin_name}" "${OS_NAME}" "${TEMP_DIRECTORY}" BUNDLE_NAME)
  if(NOT BUNDLE_NAME STREQUAL "")
    file(COPY "${TEMP_DIRECTORY}/${BUNDLE_NAME}" DESTINATION "${WORKING_DIRECTORY}")
  else()
    pvp_copy_files("${TEMP_DIRECTORY}" "dll" "${WORKING_DIRECTORY}")
    pvp_copy_files("${TEMP_DIRECTORY}" "cat" "${WORKING_DIRECTORY}")
  endif()
  pvp_get_install_names(${plugin_name} PLUGIN_INSTALL_NAMES)
  list(GET PLUGIN_INSTALL_NAMES 1 PLUGIN_ALT_NAME)
  set(${plugin_name}_BUNDLE_NAME "${BUNDLE_NAME}" PARENT_SCOPE)
  set(${plugin_name}_ALT_NAME "${PLUGIN_ALT_NAME}" PARENT_SCOPE)
  set(${plugin_name}_PLUGIN_VERSION "${plugin_version}" PARENT_SCOPE)
  list(APPEND PVP_PLUGINS ${plugin_name})
  set(PVP_PLUGINS "${PVP_PLUGINS}" PARENT_SCOPE)
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
endfunction()

pvp_prepare_plugins()

# Check that all the files of the plugins (the .vamp bundle or the legacy
# library + cat files) have been retrieved.
foreach(PLUGIN_NAME ${PVP_PLUGINS})
  if(NOT ${PLUGIN_NAME}_BUNDLE_NAME STREQUAL "")
    set(PLUGIN_REQUIRED_FILES "${${PLUGIN_NAME}_BUNDLE_NAME}")
  else()
    set(PLUGIN_REQUIRED_FILES "${PLUGIN_NAME}.dll" "${PLUGIN_NAME}.cat")
  endif()
  foreach(REQUIRED_FILE ${PLUGIN_REQUIRED_FILES})
    if(NOT EXISTS "${WORKING_DIRECTORY}/${REQUIRED_FILE}")
      message(FATAL_ERROR "The file ${REQUIRED_FILE} is missing to generate the Windows package.")
    endif()
  endforeach()
endforeach()

# The plugin-dependent sections of the Inno Setup script (the components,
# the removal of the previous versions of the plugins and the files of the
# plugins) are generated from the plugins.json definitions and the script is
# configured from the resource/windows-package.iss.in template.
set(PVP_COMPONENTS "")
set(PVP_INSTALL_DELETES "")
set(PVP_FILES "")
foreach(PLUGIN_NAME ${PVP_PLUGINS})
  string(TOLOWER "${PLUGIN_NAME}" COMPONENT_NAME)
  string(APPEND PVP_COMPONENTS "Name: \"${COMPONENT_NAME}\"; Description: \"${PLUGIN_NAME}\"; Types: full\n")
  pvp_get_install_names("${PLUGIN_NAME}" PLUGIN_INSTALL_NAMES)
  foreach(PLUGIN_INSTALL_NAME ${PLUGIN_INSTALL_NAMES})
    string(APPEND PVP_INSTALL_DELETES "Type: files; Name: \"{app}\\${PLUGIN_INSTALL_NAME}.dll\"; Components: ${COMPONENT_NAME}\n")
    string(APPEND PVP_INSTALL_DELETES "Type: files; Name: \"{app}\\${PLUGIN_INSTALL_NAME}.cat\"; Components: ${COMPONENT_NAME}\n")
    string(APPEND PVP_INSTALL_DELETES "Type: filesandordirs; Name: \"{app}\\${PLUGIN_INSTALL_NAME}.vamp\"; Components: ${COMPONENT_NAME}\n")
  endforeach()
  # The models of the previous versions of the plugins were installed outside
  # of the Vamp directory (e.g. the VAX and Whisper models in the ProgramData
  # directory), they are removed at the installation of the plugin.
  if(DEFINED ${PLUGIN_NAME}_LEGACY_MODELS AND NOT "${${PLUGIN_NAME}_LEGACY_MODELS}" STREQUAL "")
    string(APPEND PVP_INSTALL_DELETES "Type: filesandordirs; Name: \"{commonappdata}\\Ircam\\${${PLUGIN_NAME}_LEGACY_MODELS}\"; Components: ${COMPONENT_NAME}\n")
  endif()
  if(NOT ${PLUGIN_NAME}_BUNDLE_NAME STREQUAL "")
    # Inno Setup only matches files and wildcards in Source (a directory name
    # alone matches nothing), therefore the contents of the .vamp bundle are
    # installed with the "dir\*" wildcard form (into the bundle directory of
    # the destination).
    string(APPEND PVP_FILES "Source: \"{#MyPackageFolder}\\${${PLUGIN_NAME}_BUNDLE_NAME}\\*\"; DestDir: \"{app}\\${${PLUGIN_NAME}_BUNDLE_NAME}\"; Components: ${COMPONENT_NAME}; Flags: recursesubdirs createallsubdirs\n")
  else()
    string(APPEND PVP_FILES "Source: \"{#MyPackageFolder}\\${PLUGIN_NAME}.dll\"; DestDir: \"{app}\"; Components: ${COMPONENT_NAME}; Flags: ignoreversion\n")
    string(APPEND PVP_FILES "Source: \"{#MyPackageFolder}\\${PLUGIN_NAME}.cat\"; DestDir: \"{app}\"; Components: ${COMPONENT_NAME}; Flags: ignoreversion\n")
  endif()
endforeach()
configure_file("${PVP_RESOURCE_DIR}/windows-package.iss.in" "${WORKING_DIRECTORY}/windows-package.iss" @ONLY)

find_program(ISCC_EXE "iscc" HINTS "C:/Program Files (x86)/Inno Setup 6" REQUIRED)
execute_process(COMMAND ${ISCC_EXE} "/DMyAppVerName=${PVP_BUILD_TAG}" "/DMyPackageFolder=${WORKING_DIRECTORY}" "/O${WORKING_DIRECTORY}" "${WORKING_DIRECTORY}/windows-package.iss" RESULT_VARIABLE ISCC_RESULT)
if(NOT ISCC_RESULT EQUAL 0)
  message(FATAL_ERROR "The generation of the Windows installer failed (iscc error code ${ISCC_RESULT}).")
endif()
set(INSTALLER_PATH "${WORKING_DIRECTORY}/Partiels Vamp Plugins-install.exe")

file(COPY "${INSTALLER_PATH}" DESTINATION "${PVP_OUTPUT_DIRECTORY}")

# Generate one installer per plugin with the windows-plugin-package template.
# The installer is copied in the Plugins directory of the repository next to
# the bundle installer.
if(PVP_GENERATE_PLUGIN_INSTALLERS)
  foreach(PLUGIN_NAME ${PVP_PLUGINS})
    set(PLUGIN_INSTALLER_PATH "${WORKING_DIRECTORY}/${PLUGIN_NAME}-install.exe")
    set(ISCC_OPTIONS "/DMyAppVerName=${PVP_BUILD_TAG}" "/DMyPluginVerName=${${PLUGIN_NAME}_PLUGIN_VERSION}" "/DMyPackageFolder=${WORKING_DIRECTORY}" "/DMyPluginName=${PLUGIN_NAME}" "/DMyPluginAltName=${${PLUGIN_NAME}_ALT_NAME}")
    if(NOT ${PLUGIN_NAME}_BUNDLE_NAME STREQUAL "")
      list(APPEND ISCC_OPTIONS "/DMyPluginBundleName=${${PLUGIN_NAME}_BUNDLE_NAME}")
    endif()
    if(DEFINED ${PLUGIN_NAME}_LEGACY_MODELS AND NOT "${${PLUGIN_NAME}_LEGACY_MODELS}" STREQUAL "")
      list(APPEND ISCC_OPTIONS "/DMyPluginLegacyModels=${${PLUGIN_NAME}_LEGACY_MODELS}")
    endif()
    execute_process(COMMAND ${ISCC_EXE} ${ISCC_OPTIONS} "/O${WORKING_DIRECTORY}" "${PVP_RESOURCE_DIR}/windows-plugin-package.iss" RESULT_VARIABLE ISCC_RESULT)
    if(NOT ISCC_RESULT EQUAL 0)
      message(FATAL_ERROR "The generation of the installer of ${PLUGIN_NAME} failed (iscc error code ${ISCC_RESULT}).")
    endif()
    file(COPY "${PLUGIN_INSTALLER_PATH}" DESTINATION "${PVP_OUTPUT_DIRECTORY}")
  endforeach()
endif()
