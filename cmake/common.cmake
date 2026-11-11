# The helpers shared by the package generations.
# Retrieve the name of a plugin in lowercase without the characters that are
# not alphanumeric (e.g. My-Plugin and myplugin), used for the identifiers of
# the installers (Inno Setup components).
function(pvp_get_lower_name plugin_name out_name)
string(TOLOWER "${plugin_name}" PLUGIN_NAME_LOWER)
string(REGEX REPLACE "[^a-z0-9]" "" PLUGIN_NAME_LOWER "${PLUGIN_NAME_LOWER}")
set(${out_name} "${PLUGIN_NAME_LOWER}" PARENT_SCOPE)
endfunction()

# Retrieve the names under which the versions of a plugin can have been installed:
# the legacy name of the plugin (library + cat files), the identifier of the
# plugin, which is the name of the .vamp bundle (and of the library of the plugin,
# hence the prefix of the plugin keys) that can't be deduced from the name of the
# plugin (e.g. SuperVP and ircamsvp, IrcamBeat and ircambeat, IPT and ircamipt),
# and the identifiers of the previous versions of the plugin (e.g. supervp).
function(pvp_get_install_names plugin_name out_names)
if("${${plugin_name}_IDENTIFIER}" STREQUAL "")
  message(FATAL_ERROR "The identifier of " ${plugin_name} " is not defined.")
endif()
set(INSTALL_NAMES "${plugin_name}" "${${plugin_name}_IDENTIFIER}" ${${plugin_name}_LEGACY_IDENTIFIERS})
list(REMOVE_DUPLICATES INSTALL_NAMES)
set(${out_names} "${INSTALL_NAMES}" PARENT_SCOPE)
endfunction()

# Check that the .vamp bundle of a plugin (if any) is named after the
# identifier of the plugin, otherwise the bundle would not be removed by the
# next installations and by the uninstallation of the plugin.
function(pvp_check_bundle_name plugin_name bundle_name)
if(NOT bundle_name STREQUAL "" AND NOT bundle_name STREQUAL "${${plugin_name}_IDENTIFIER}.vamp")
  message(FATAL_ERROR "The bundle ${bundle_name} of ${plugin_name} doesn't match its identifier ${${plugin_name}_IDENTIFIER} (see resource/plugins.json).")
endif()
endfunction()

# The shell commands that remove the files of a plugin under all the names
# under which it can have been installed (see pvp_get_install_names), with
# the given shell function (e.g. clean_plugin or uninstall_plugin) called
# with the given directory, the install name and the extra arguments.
function(pvp_get_remove_commands plugin_name function_name directory extra_arguments out_commands)
pvp_get_install_names("${plugin_name}" PLUGIN_INSTALL_NAMES)
set(COMMANDS "")
foreach(PLUGIN_INSTALL_NAME ${PLUGIN_INSTALL_NAMES})
  string(APPEND COMMANDS "    ${function_name} \"${directory}\" \"${PLUGIN_INSTALL_NAME}\"${extra_arguments}\n")
endforeach()
set(${out_commands} "${COMMANDS}" PARENT_SCOPE)
endfunction()

# Copy files with a specific extension package
function(pvp_copy_files directory extension destination)
file(GLOB FILE_PATHS "${directory}/*.${extension}")
file(COPY "${FILE_PATHS}" DESTINATION "${destination}")
endfunction()

# Append the description of a plugin (with its version) to the About file.
function(pvp_append_about plugin_name plugin_version about_file)
file(APPEND "${about_file}" "- ${plugin_name} v${plugin_version}: ${${plugin_name}_DESCRIPTION}\n")
endfunction()

# Prepare the temporary directory used to extract the files of a plugin.
macro(pvp_reset_temp_directory)
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")
  file(MAKE_DIRECTORY "${TEMP_DIRECTORY}")
endmacro()

# Write the header of the About file of a package.
macro(pvp_write_about_header directory)
  file(WRITE "${directory}/About.txt" "This package is a bundle of Vamp plugins developed at Ircam for Partiels.\n\n")
endmacro()

# The shell commands that remove the legacy models directory of a plugin (the
# previous versions of the plugins installed their models outside of the Vamp
# directory, e.g. the VAX and Whisper models). The base directory depends on
# the operating system (e.g. "$HOME/.config/Ircam" on Linux and
# "/Library/Application Support/Ircam" on MacOS) and the commands are empty
# for the plugins that never installed models outside of the Vamp directory.
function(pvp_get_legacy_models_commands plugin_name base_directory out_commands)
  set(COMMANDS "")
  if(DEFINED ${plugin_name}_LEGACY_MODELS AND NOT "${${plugin_name}_LEGACY_MODELS}" STREQUAL "")
    string(APPEND COMMANDS "    rm -rf \"${base_directory}/${${plugin_name}_LEGACY_MODELS}\"\n")
  endif()
  set(${out_commands} "${COMMANDS}" PARENT_SCOPE)
endfunction()

# Encode a string as a JSON string value (the STRING_ENCODE subcommand of
# string(JSON) requires CMake 3.26 and the continuous integration runners
# ship older versions, therefore the string is escaped manually).
function(pvp_json_encode value out_var)
  set(ENCODED "${value}")
  string(REPLACE "\\" "\\\\" ENCODED "${ENCODED}")
  string(REPLACE "\"" "\\\"" ENCODED "${ENCODED}")
  string(REPLACE "\n" "\\n" ENCODED "${ENCODED}")
  string(REPLACE "\r" "\\r" ENCODED "${ENCODED}")
  string(REPLACE "\t" "\\t" ENCODED "${ENCODED}")
  set(${out_var} "\"${ENCODED}\"" PARENT_SCOPE)
endfunction()
