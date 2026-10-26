# The download of the packages of the plugins: from the artifacts of the
# Ircam Forge 2 or from the releases of GitHub, and the extraction of the
# .vamp bundle of a package.
#
# The downloaded zip files are cached in the PVP_CACHE_DIRECTORY (if defined)
# so that the packages are not downloaded again (e.g. on the continuous
# integration, when the plugins.json file has not changed). The name of the
# cached zip files is derived from the name of the plugin, its ref and the
# kind of package (the operating system or the job name), therefore the cache
# is automatically invalidated when one of them changes. The packages of the
# plugins hosted on the Ircam Forge 2 whose ref is a branch are not cached.

# Download a package from the Ircam Forge 2 and copy its content in the destination directory.
function(pvp_download_package plugin_name project_id project_ref job_name destination)
  message(STATUS "  Download package " ${plugin_name} " (" ${project_id} " " ${project_ref} " " ${job_name} ") to " ${destination})
  set(TEMP_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Temp")
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
  file(MAKE_DIRECTORY "${TEMP_DIRECTORY}")

  # Only the refs that are versions (e.g. 5.0.0 or v5.0.0) are cached: a
  # branch evolves while its name remains the same, therefore its package is
  # always downloaded.
  set(ZIP_PATH "${TEMP_DIRECTORY}/${plugin_name}.zip")
  if(NOT "${PVP_CACHE_DIRECTORY}" STREQUAL "" AND project_ref MATCHES "^v?[0-9]+(\\.[0-9]+)*$")
    string(REPLACE "::" "-" CACHE_KEY "${job_name}")
    set(ZIP_PATH "${PVP_CACHE_DIRECTORY}/${plugin_name}-${project_ref}-${CACHE_KEY}.zip")
  endif()

  if(NOT EXISTS "${ZIP_PATH}")
    if("${PRIVATE_TOKEN}" STREQUAL "")
      message(FATAL_ERROR "The private token of the Ircam Forge 2 is not defined: the package of " ${plugin_name} " hosted on the forge cannot be downloaded (define PRIVATE_TOKEN or the FORGE_PRIVATE_TOKEN environment variable).")
    endif()
    set(PACKAGE_PROJECT_URL "https://forge-2.ircam.fr/api/v4/projects/${project_id}/jobs/artifacts/${project_ref}/download?job=${job_name}")
    # The Ircam Forge 2 sometimes returns transient errors (e.g. 502),
    # therefore the download is attempted a few times.
    set(DOWNLOAD_RESULT_CODE 1)
    foreach(DOWNLOAD_ATTEMPT RANGE 1 3)
      file(DOWNLOAD ${PACKAGE_PROJECT_URL} "${ZIP_PATH}" HTTPHEADER "PRIVATE-TOKEN: ${PRIVATE_TOKEN}" STATUS DOWNLOAD_RESULT LOG DOWNLOAD_LOG)
      list(GET DOWNLOAD_RESULT 0 DOWNLOAD_RESULT_CODE)
      if(DOWNLOAD_RESULT_CODE EQUAL 0)
        break()
      endif()
      if(NOT DOWNLOAD_ATTEMPT EQUAL 3)
        message(WARNING "The download of ${plugin_name} failed (attempt ${DOWNLOAD_ATTEMPT}, error ${DOWNLOAD_RESULT}), retrying in 15 seconds...")
        execute_process(COMMAND sleep 15)
      endif()
    endforeach()
    if(NOT DOWNLOAD_RESULT_CODE EQUAL 0)
      file(REMOVE "${ZIP_PATH}")
      string(FIND "${DOWNLOAD_LOG}" " 401 " UNAUTHORIZED_POSITION)
      if(NOT UNAUTHORIZED_POSITION EQUAL -1)
        message(FATAL_ERROR "Failed downloading! Error: ${DOWNLOAD_RESULT}.\nThe Ircam Forge 2 rejected the token: the private token might be invalid or expired.")
      endif()
      message(FATAL_ERROR "Failed downloading! Error: ${DOWNLOAD_RESULT} - ${DOWNLOAD_LOG}.")
    endif()
  else()
    message(STATUS "  Cached package " ${ZIP_PATH})
  endif()

  file(ARCHIVE_EXTRACT INPUT "${ZIP_PATH}" DESTINATION "${TEMP_DIRECTORY}")
  if(EXISTS "${TEMP_DIRECTORY}/${plugin_name}.zip")
    file(REMOVE "${TEMP_DIRECTORY}/${plugin_name}.zip")
  endif()

  file(GLOB CHILD_PATHS "${TEMP_DIRECTORY}/*")
  foreach(CHILD_PATH ${CHILD_PATHS})
    if(IS_DIRECTORY "${CHILD_PATH}")
      file(COPY "${CHILD_PATH}/" DESTINATION "${destination}")
    else()
      file(COPY "${CHILD_PATH}" DESTINATION "${destination}")
    endif()
  endforeach()

  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
endfunction()

# Download a release package of a plugin hosted on GitHub and extract it in the destination directory.
# The project ref is the release tag, or "latest" to use the most recent release.
function(pvp_download_github_package plugin_name repository_name project_ref os_name destination out_version)
  message(STATUS "  Download package " ${plugin_name} " (" ${repository_name} " " ${project_ref} " " ${os_name} ") to " ${destination})
  set(TEMP_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Temp")
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
  file(MAKE_DIRECTORY "${TEMP_DIRECTORY}")

  set(TAG_NAME "${project_ref}")
  if(TAG_NAME STREQUAL "" OR TAG_NAME STREQUAL "latest")
    pvp_get_github_latest_tag("${repository_name}" TAG_NAME)
    message(STATUS "  Latest version of " ${plugin_name} " is " ${TAG_NAME})
  endif()

  set(ZIP_PATH "${TEMP_DIRECTORY}/${plugin_name}.zip")
  if(NOT "${PVP_CACHE_DIRECTORY}" STREQUAL "")
    set(ZIP_PATH "${PVP_CACHE_DIRECTORY}/${plugin_name}-${TAG_NAME}-${os_name}.zip")
  endif()

  if(NOT EXISTS "${ZIP_PATH}")
    set(PACKAGE_PROJECT_URL "https://github.com/${repository_name}/releases/download/${TAG_NAME}/${plugin_name}-Vamp-${os_name}.zip")
    set(DOWNLOAD_RESULT_CODE 1)
    foreach(DOWNLOAD_ATTEMPT RANGE 1 3)
      file(DOWNLOAD ${PACKAGE_PROJECT_URL} "${ZIP_PATH}" STATUS DOWNLOAD_RESULT LOG DOWNLOAD_LOG)
      list(GET DOWNLOAD_RESULT 0 DOWNLOAD_RESULT_CODE)
      if(DOWNLOAD_RESULT_CODE EQUAL 0)
        break()
      endif()
      if(NOT DOWNLOAD_ATTEMPT EQUAL 3)
        message(WARNING "The download of ${plugin_name} failed (attempt ${DOWNLOAD_ATTEMPT}, error ${DOWNLOAD_RESULT}), retrying in 15 seconds...")
        execute_process(COMMAND sleep 15)
      endif()
    endforeach()
    if(NOT DOWNLOAD_RESULT_CODE EQUAL 0)
      file(REMOVE "${ZIP_PATH}")
      message(FATAL_ERROR "Failed downloading! Error: ${DOWNLOAD_RESULT} - ${DOWNLOAD_LOG}.")
    endif()
  else()
    message(STATUS "  Cached package " ${ZIP_PATH})
  endif()

  file(ARCHIVE_EXTRACT INPUT "${ZIP_PATH}" DESTINATION "${destination}")
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
  set(${out_version} "${TAG_NAME}" PARENT_SCOPE)
endfunction()

# Extract the .vamp bundle of a plugin package if any.
# Some packages (e.g. VAX) contain a zip file (PLUGIN-Vamp-OS.zip) with the .vamp bundle.
function(pvp_extract_bundle plugin_name os_name directory out_bundle_name)
  if(EXISTS "${directory}/${plugin_name}-Vamp-${os_name}.zip")
    file(ARCHIVE_EXTRACT INPUT "${directory}/${plugin_name}-Vamp-${os_name}.zip" DESTINATION "${directory}")
    file(REMOVE "${directory}/${plugin_name}-Vamp-${os_name}.zip")
  endif()
  file(GLOB BUNDLE_PATHS "${directory}/*.vamp")
  set(BUNDLE_NAME "")
  foreach(BUNDLE_PATH ${BUNDLE_PATHS})
    get_filename_component(BUNDLE_NAME "${BUNDLE_PATH}" NAME)
  endforeach()
  set(${out_bundle_name} "${BUNDLE_NAME}" PARENT_SCOPE)
endfunction()

# Retrieve the tag of the most recent release of a repository hosted on GitHub.
# The request is authenticated with the GITHUB_TOKEN environment variable if
# defined (the unauthenticated requests of the GitHub API are limited to 60
# per hour and per IP address, which is easily reached on the shared runners
# of the continuous integration).
function(pvp_get_github_latest_tag repository_name out_tag)
  set(RELEASE_PROJECT_URL "https://api.github.com/repos/${repository_name}/releases/latest")
  set(RELEASE_HEADERS HTTPHEADER "Accept: application/vnd.github+json")
  if(NOT "$ENV{GITHUB_TOKEN}" STREQUAL "")
    list(APPEND RELEASE_HEADERS HTTPHEADER "Authorization: Bearer $ENV{GITHUB_TOKEN}")
  endif()
  file(DOWNLOAD ${RELEASE_PROJECT_URL} "${CMAKE_CURRENT_BINARY_DIR}/release.json" ${RELEASE_HEADERS} STATUS DOWNLOAD_RESULT LOG DOWNLOAD_LOG)
  list(GET DOWNLOAD_RESULT 0 DOWNLOAD_RESULT_CODE)
  if(NOT DOWNLOAD_RESULT_CODE EQUAL 0)
    message(FATAL_ERROR "Failed downloading! Error: ${DOWNLOAD_RESULT} - ${DOWNLOAD_LOG}.")
  endif()
  file(READ "${CMAKE_CURRENT_BINARY_DIR}/release.json" RELEASE_JSON)
  string(REGEX MATCH "\"tag_name\": *\"[^\"]*\"" TAG_NAME_MATCHED "${RELEASE_JSON}")
  if(TAG_NAME_MATCHED STREQUAL "")
    message(FATAL_ERROR "Failed retrieving the latest version of " ${repository_name} "!")
  endif()
  string(REGEX REPLACE "\"tag_name\": *\"([^\"]*)\"" "\\1" TAG_NAME "${TAG_NAME_MATCHED}")
  file(REMOVE "${CMAKE_CURRENT_BINARY_DIR}/release.json")
  set(${out_tag} "${TAG_NAME}" PARENT_SCOPE)
endfunction()
