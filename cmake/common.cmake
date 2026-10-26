# The helpers shared by the package generations.
# Retrieve the names under which the versions of a plugin can have been installed:
# the legacy name of the plugin (library + cat files) and the name formatted
# for the .vamp bundle (e.g. IrcamBeat and ircambeat, IPT and ircamipt).
function(pvp_get_install_names plugin_name out_names)
string(TOLOWER "${plugin_name}" PLUGIN_NAME_LOWER)
set(INSTALL_NAMES "${plugin_name}")
string(FIND "${PLUGIN_NAME_LOWER}" "ircam" IRCAM_POSITION)
if(IRCAM_POSITION EQUAL 0)
  list(APPEND INSTALL_NAMES "${PLUGIN_NAME_LOWER}")
else()
  list(APPEND INSTALL_NAMES "ircam${PLUGIN_NAME_LOWER}")
endif()
set(${out_names} "${INSTALL_NAMES}" PARENT_SCOPE)
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
