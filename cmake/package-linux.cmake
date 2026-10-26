# The generation of the Linux packages: the plugins are installed in "$HOME/vamp",
# the package is a directory with an Install.sh script (the plugins can be
# selected with the arguments of the script, with the option --all, or
# interactively) and one standalone installation directory per plugin. This
# generation does not depend on the operating system.
message(STATUS "Preparing Linux package")

set(OS_NAME "Linux")
set(JOB_NAME "Build::Linux")
set(WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/Linux")
file(REMOVE_RECURSE "${WORKING_DIRECTORY}")
file(MAKE_DIRECTORY "${WORKING_DIRECTORY}")
set(TEMP_DIRECTORY "${WORKING_DIRECTORY}/Temp")

pvp_write_about_header("${WORKING_DIRECTORY}")

# The commands that remove the previous versions of the plugin (the legacy
# library + cat files and the .vamp bundle) and that copy the files of the
# plugin (the .vamp bundle or the legacy library + cat files) in the vamp
# directory of the user. The commands are shared by the installation block
# of the plugin (in the Install.sh script of the package) and by the
# standalone installer of the plugin.
function(pvp_plugin_commands plugin_name bundle_name out_commands)
  pvp_get_install_names("${plugin_name}" PLUGIN_INSTALL_NAMES)
  set(COMMANDS "")
  foreach(PLUGIN_INSTALL_NAME ${PLUGIN_INSTALL_NAMES})
    string(APPEND COMMANDS "    clean_plugin \"$HOME/vamp\" ${PLUGIN_INSTALL_NAME}\n")
  endforeach()
  # The models of the previous versions of the plugins were installed outside
  # of the vamp directory (e.g. the VAX and Whisper models), they are removed.
  pvp_get_legacy_models_commands("${plugin_name}" "$HOME/.config/Ircam" PLUGIN_LEGACY_MODELS_COMMANDS)
  string(APPEND COMMANDS "${PLUGIN_LEGACY_MODELS_COMMANDS}")
  string(APPEND COMMANDS "\n")
  if(NOT bundle_name STREQUAL "")
    string(APPEND COMMANDS "    cp -R \"$ThisPath/${bundle_name}\" \"$HOME/vamp/\"\n")
  else()
    string(APPEND COMMANDS "    cp -f \"$ThisPath/${plugin_name}.so\" \"$ThisPath/${plugin_name}.cat\" \"$HOME/vamp/\"\n")
  endif()
  set(${out_commands} "${COMMANDS}" PARENT_SCOPE)
endfunction()

# The installation blocks of the plugins are generated from the
# resource/linux-install-block.sh.in template during their preparation and
# the Install.sh script is assembled at the end of the generation so that
# the plugins can be selected by the user at the installation.
set(PVP_PLUGINS "")
set(PVP_INSTALL_BLOCKS "")

function(pvp_finalize_plugin plugin_name plugin_version)
  pvp_append_about(${plugin_name} ${plugin_version} "${WORKING_DIRECTORY}/About.txt")
  pvp_extract_bundle("${plugin_name}" "${OS_NAME}" "${TEMP_DIRECTORY}" BUNDLE_NAME)

  # The files of the plugin are copied in the package directory and the
  # installation block of the plugin (that only runs if the user selected
  # the plugin) is added to the Install.sh script of the package.
  pvp_plugin_commands("${plugin_name}" "${BUNDLE_NAME}" PVP_PLUGIN_COMMANDS)
  set(PLUGIN_NAME "${plugin_name}")
  configure_file("${PVP_RESOURCE_DIR}/linux-install-block.sh.in" "${CMAKE_CURRENT_BINARY_DIR}/InstallBlock.sh" @ONLY)
  file(READ "${CMAKE_CURRENT_BINARY_DIR}/InstallBlock.sh" PLUGIN_INSTALL_BLOCK)
  file(REMOVE "${CMAKE_CURRENT_BINARY_DIR}/InstallBlock.sh")
  string(APPEND PVP_INSTALL_BLOCKS "${PLUGIN_INSTALL_BLOCK}")
  set(PVP_INSTALL_BLOCKS "${PVP_INSTALL_BLOCKS}" PARENT_SCOPE)
  if(NOT BUNDLE_NAME STREQUAL "")
    file(COPY "${TEMP_DIRECTORY}/${BUNDLE_NAME}" DESTINATION "${WORKING_DIRECTORY}")
  else()
    pvp_copy_files("${TEMP_DIRECTORY}" "so" "${WORKING_DIRECTORY}")
    pvp_copy_files("${TEMP_DIRECTORY}" "cat" "${WORKING_DIRECTORY}")
  endif()

  # Prepare the standalone package of the plugin: a directory that contains
  # the files of the plugin, an installation script (generated from the
  # resource/linux-plugin-install.sh.in template) that only installs this
  # plugin and an uninstallation script (generated from the
  # resource/linux-plugin-uninstall.sh.in template) that only removes this
  # plugin (without asking the user to select the plugins).
  if(PVP_GENERATE_PLUGIN_INSTALLERS)
    set(PLUGIN_DIRECTORY "${WORKING_DIRECTORY}/${plugin_name}")
    file(MAKE_DIRECTORY "${PLUGIN_DIRECTORY}")
    if(NOT BUNDLE_NAME STREQUAL "")
      file(COPY "${TEMP_DIRECTORY}/${BUNDLE_NAME}" DESTINATION "${PLUGIN_DIRECTORY}")
    else()
      file(COPY "${TEMP_DIRECTORY}/${plugin_name}.so" "${TEMP_DIRECTORY}/${plugin_name}.cat" DESTINATION "${PLUGIN_DIRECTORY}")
    endif()
    pvp_get_install_names("${plugin_name}" PLUGIN_INSTALL_NAMES)
    list(GET PLUGIN_INSTALL_NAMES 1 PVP_PLUGIN_ALT_NAME)
    pvp_get_legacy_models_commands("${plugin_name}" "$HOME/.config/Ircam" PVP_PLUGIN_LEGACY_MODELS_COMMANDS)
    configure_file("${PVP_RESOURCE_DIR}/linux-plugin-install.sh.in" "${PLUGIN_DIRECTORY}/Install.sh" @ONLY)
    file(CHMOD "${PLUGIN_DIRECTORY}/Install.sh" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    configure_file("${PVP_RESOURCE_DIR}/linux-plugin-uninstall.sh.in" "${PLUGIN_DIRECTORY}/Uninstall.sh" @ONLY)
    file(CHMOD "${PLUGIN_DIRECTORY}/Uninstall.sh" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
  endif()

  list(APPEND PVP_PLUGINS ${plugin_name})
  set(PVP_PLUGINS "${PVP_PLUGINS}" PARENT_SCOPE)
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
endfunction()

pvp_prepare_plugins()

# The Install.sh script is assembled from the resource/linux-install.sh.in
# template and the installation blocks of the plugins (in the order of
# their preparation). It allows the user to select the plugins to install:
#  - the plugins can be passed as arguments of the script,
#  - the option --all installs all the plugins,
#  - otherwise the plugins are prompted one by one (with a terminal),
#  - without a terminal, all the plugins are installed.
string(REPLACE ";" " " PVP_PLUGINS_STRING "${PVP_PLUGINS}")
configure_file("${PVP_RESOURCE_DIR}/linux-install.sh.in" "${WORKING_DIRECTORY}/Install.sh" @ONLY)
file(CHMOD "${WORKING_DIRECTORY}/Install.sh" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

# The Uninstall.sh script is assembled from the resource/linux-uninstall.sh.in
# template and the uninstallation blocks of all the plugins (it removes the
# plugins whether they have been installed with this package or with the
# standalone packages of the plugins).
string(REPLACE ";" " " PVP_PLUGINS_STRING "${PVP_ALL_PLUGINS}")
set(PVP_UNINSTALL_BLOCKS "")
foreach(PLUGIN_NAME ${PVP_ALL_PLUGINS})
  pvp_get_install_names("${PLUGIN_NAME}" PLUGIN_INSTALL_NAMES)
  list(GET PLUGIN_INSTALL_NAMES 1 PVP_PLUGIN_ALT_NAME)
  pvp_get_legacy_models_commands("${PLUGIN_NAME}" "$HOME/.config/Ircam" PVP_PLUGIN_LEGACY_MODELS_COMMANDS)
  set(PLUGIN_NAME "${PLUGIN_NAME}")
  configure_file("${PVP_RESOURCE_DIR}/linux-uninstall-block.sh.in" "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh" @ONLY)
  file(READ "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh" PLUGIN_UNINSTALL_BLOCK)
  file(REMOVE "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh")
  string(APPEND PVP_UNINSTALL_BLOCKS "${PLUGIN_UNINSTALL_BLOCK}")
endforeach()
configure_file("${PVP_RESOURCE_DIR}/linux-uninstall.sh.in" "${WORKING_DIRECTORY}/Uninstall.sh" @ONLY)
file(CHMOD "${WORKING_DIRECTORY}/Uninstall.sh" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
file(REMOVE_RECURSE "${PVP_OUTPUT_DIRECTORY}/Partiels-Vamp-Plugins-Linux")
file(RENAME "${WORKING_DIRECTORY}" "${PVP_OUTPUT_DIRECTORY}/Partiels-Vamp-Plugins-Linux")
