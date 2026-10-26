# The generation of the manuals package: the manuals of the plugins are
# retrieved from the Doc artifacts of the Ircam Forge 2. This generation does
# not depend on the operating system.
message(STATUS "Preparing Manuals package")

set(WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Manuals")
file(REMOVE_RECURSE "${WORKING_DIRECTORY}")
file(MAKE_DIRECTORY "${WORKING_DIRECTORY}")

function(pvp_prepare_manual_plugin plugin_name project_id project_ref)
  pvp_download_package(${plugin_name} ${project_id} ${project_ref} "Doc" "${WORKING_DIRECTORY}")
endfunction()

foreach(PLUGIN_NAME ${PVP_ALL_PLUGINS})
  if(${PLUGIN_NAME}_MANUALS)
    string(TOUPPER "${PLUGIN_NAME}" PLUGIN_NAME_UPPER)
    pvp_prepare_manual_plugin(${PLUGIN_NAME} ${${PLUGIN_NAME}_GITLAB_ID} ${${PLUGIN_NAME_UPPER}_REF})
  endif()
endforeach()

file(REMOVE_RECURSE "${PVP_OUTPUT_DIRECTORY}/Manuals")
file(COPY "${WORKING_DIRECTORY}" DESTINATION "${PVP_OUTPUT_DIRECTORY}")
