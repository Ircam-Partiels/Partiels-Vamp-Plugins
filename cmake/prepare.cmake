# The preparation of the plugins defined in the resource/plugins.json file.
# Note that the prepare macros call the pvp_finalize_plugin macro defined by
# the package generation of the current operating system (the macros are used
# so that the variables they set in their parent scope, e.g. the distribution
# xml files of MacOS, are not discarded).

macro(prepare_plugin plugin_name project_id project_ref)
  pvp_reset_temp_directory()
  pvp_download_package(${plugin_name} ${project_id} ${project_ref} "${JOB_NAME}" "${TEMP_DIRECTORY}")
  pvp_finalize_plugin(${plugin_name} ${project_ref})
endmacro()

macro(prepare_github_plugin plugin_name repository_name project_ref)
  pvp_reset_temp_directory()
  pvp_download_github_package(${plugin_name} ${repository_name} ${project_ref} "${OS_NAME}" "${TEMP_DIRECTORY}" PLUGIN_VERSION)
  pvp_finalize_plugin(${plugin_name} ${PLUGIN_VERSION})
endmacro()

macro(pvp_prepare_plugins)
  foreach(PLUGIN_NAME ${PVP_ALL_PLUGINS})
    string(TOUPPER "${PLUGIN_NAME}" PLUGIN_NAME_UPPER)
    if(${PLUGIN_NAME}_GITLAB_ID)
      prepare_plugin(${PLUGIN_NAME} ${${PLUGIN_NAME}_GITLAB_ID} ${${PLUGIN_NAME_UPPER}_REF})
    else()
      prepare_github_plugin(${PLUGIN_NAME} ${${PLUGIN_NAME}_REPOSITORY} ${${PLUGIN_NAME_UPPER}_REF})
    endif()
  endforeach()
endmacro()
