cmake_minimum_required(VERSION 3.19)

# Generates the plugin list (Partiels-Plugins.json) consumed by the plugin
# manager of Partiels (see the WebReference class of the Partiels source).
# The properties of the plugins are defined in the resource/plugins.json
# file (see cmake/plugins.cmake) and the download URLs target the
# per-plugin installers of the release of this repository that matches the
# build tag:
#  - MacOS: a notarized package installer (pkg),
#  - Windows: a signed executable installer (exe),
#  - Linux: a zip archive that contains an installation script (Install.sh).
# The compatibility of the MacOS package is described by the minimum macOS
# version (minVersionMacos) and the supported architectures
# (architecturesMacos) of the plugin.
#
# The version of a plugin is the major part of the release tag of its
# repository (e.g. 5.0.0 gives 5; for the plugins hosted on GitHub whose
# ref is empty or "latest", the tag of their most recent release is
# retrieved with the GitHub API).
#
# Command line options:
#  - PVP_BUILD_TAG: the tag of the release of this repository (required),
#  - PVP_REPOSITORY: the GitHub repository of this package
#    (by default Ircam-Partiels/Partiels-Vamp-Plugins),
#  - PVP_OUTPUT_FILE: the path of the generated file
#    (by default Partiels-Plugins.json next to this script).
#
# Usage:
#  cmake -D PVP_BUILD_TAG="1.0.0" -P generate-plugin-list.cmake

get_filename_component(PVP_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}" ABSOLUTE)
set(PVP_RESOURCE_DIR "${PVP_ROOT_DIR}/resource")

set(PVP_REPOSITORY "Ircam-Partiels/Partiels-Vamp-Plugins" CACHE STRING "The GitHub repository of the package")
set(PVP_OUTPUT_FILE "${PVP_ROOT_DIR}/Partiels-Plugins.json" CACHE PATH "The plugin list file to generate")
set(PVP_BUILD_TAG "" CACHE STRING "The tag of the release of the package")

if(PVP_BUILD_TAG STREQUAL "")
  message(FATAL_ERROR "PVP_BUILD_TAG is not defined (the plugin list cannot be generated).")
endif()
message(STATUS "Generate the plugin list of ${PVP_REPOSITORY} ${PVP_BUILD_TAG}")

include("${PVP_ROOT_DIR}/cmake/plugins.cmake")
include("${PVP_ROOT_DIR}/cmake/common.cmake")
include("${PVP_ROOT_DIR}/cmake/download.cmake")

pvp_read_plugins()

set(RELEASE_BASE_URL "https://github.com/${PVP_REPOSITORY}/releases/download/${PVP_BUILD_TAG}")

# The version of a plugin is the major part of the release tag of its
# repository (e.g. 5.0.0 gives 5).
function(pvp_get_version_major plugin_name tag_name out_version)
  string(REGEX MATCH "^[0-9]+" PLUGIN_MAJOR "${tag_name}")
  if(PLUGIN_MAJOR STREQUAL "")
    message(FATAL_ERROR "The version of " ${plugin_name} " cannot be retrieved from the tag " ${tag_name}
      " (the tag must be formatted as major.minor.bugfix).")
  endif()
  set(${out_version} "${PLUGIN_MAJOR}" PARENT_SCOPE)
endfunction()

set(PVP_LIST "[]")
set(PVP_INDEX 0)
foreach(PLUGIN_NAME ${PVP_ALL_PLUGINS})
  string(TOUPPER "${PLUGIN_NAME}" PLUGIN_NAME_UPPER)

  # The version of the plugin: the major part of the release tag of its
  # repository (see the header of this file).
  set(PLUGIN_TAG "${${PLUGIN_NAME_UPPER}_REF}")
  if(NOT "${${PLUGIN_NAME}_REPOSITORY}" STREQUAL "" AND (PLUGIN_TAG STREQUAL "" OR PLUGIN_TAG STREQUAL "latest"))
    pvp_get_github_latest_tag("${${PLUGIN_NAME}_REPOSITORY}" PLUGIN_TAG)
  endif()
  pvp_get_version_major("${PLUGIN_NAME}" "${PLUGIN_TAG}" PLUGIN_VERSION)

  # The entry of the plugin in the list. The values of the string members
  # must be JSON encoded, therefore they are encoded with the STRING_ENCODE
  # subcommand (the version is stored as a number).
  set(PLUGIN_ENTRY "{}")
  pvp_json_encode("${${PLUGIN_NAME}_IDENTIFIER}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "identifier" "${PLUGIN_VALUE}")
  pvp_json_encode("${PLUGIN_NAME}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "name" "${PLUGIN_VALUE}")
  pvp_json_encode("${${PLUGIN_NAME}_DESCRIPTION}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "libraryDescription" "${PLUGIN_VALUE}")
  # The features are stored as a list in the plugins.json file, the plugin
  # manager of Partiels expects them as a comma separated string.
  set(PLUGIN_FEATURES_STRING "")
  foreach(PLUGIN_FEATURE ${${PLUGIN_NAME}_FEATURES})
    if(PLUGIN_FEATURES_STRING STREQUAL "")
      set(PLUGIN_FEATURES_STRING "${PLUGIN_FEATURE}")
    else()
      string(APPEND PLUGIN_FEATURES_STRING ", ${PLUGIN_FEATURE}")
    endif()
  endforeach()
  pvp_json_encode("${PLUGIN_FEATURES_STRING}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "pluginDescription" "${PLUGIN_VALUE}")
  pvp_json_encode("${${PLUGIN_NAME}_MAKER}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "maker" "${PLUGIN_VALUE}")
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "version" ${PLUGIN_VERSION})
  pvp_json_encode("${RELEASE_BASE_URL}/${PLUGIN_NAME}-Linux.zip" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "downloadUrlLinux" "${PLUGIN_VALUE}")
  pvp_json_encode("${RELEASE_BASE_URL}/${PLUGIN_NAME}-MacOS.pkg" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "downloadUrlMacos" "${PLUGIN_VALUE}")
  pvp_json_encode("${RELEASE_BASE_URL}/${PLUGIN_NAME}-Windows.exe" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "downloadUrlWindows" "${PLUGIN_VALUE}")
  # The compatibility of the MacOS package: the minimum macOS version and the
  # supported architectures (e.g. the plugins based on deep learning models
  # only support the Apple Silicon machines).
  pvp_json_encode("${${PLUGIN_NAME}_MIN_OS}" PLUGIN_VALUE)
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "minVersionMacos" "${PLUGIN_VALUE}")
  set(PLUGIN_ARCHITECTURES "[]")
  set(PLUGIN_ARCHITECTURE_INDEX 0)
  foreach(PLUGIN_ARCHITECTURE ${${PLUGIN_NAME}_ARCHITECTURES})
    pvp_json_encode("${PLUGIN_ARCHITECTURE}" PLUGIN_VALUE)
    string(JSON PLUGIN_ARCHITECTURES SET "${PLUGIN_ARCHITECTURES}" ${PLUGIN_ARCHITECTURE_INDEX} "${PLUGIN_VALUE}")
    math(EXPR PLUGIN_ARCHITECTURE_INDEX "${PLUGIN_ARCHITECTURE_INDEX} + 1")
  endforeach()
  string(JSON PLUGIN_ENTRY SET "${PLUGIN_ENTRY}" "architecturesMacos" "${PLUGIN_ARCHITECTURES}")
  string(JSON PVP_LIST SET "${PVP_LIST}" ${PVP_INDEX} "${PLUGIN_ENTRY}")

  message(STATUS "  Add " ${${PLUGIN_NAME}_IDENTIFIER} " v${PLUGIN_VERSION}")
  math(EXPR PVP_INDEX "${PVP_INDEX} + 1")
endforeach()

file(WRITE "${PVP_OUTPUT_FILE}" "${PVP_LIST}\n")
message(STATUS "The plugin list has been generated: ${PVP_OUTPUT_FILE}")
