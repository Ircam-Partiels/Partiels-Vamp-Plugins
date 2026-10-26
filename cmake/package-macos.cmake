# The generation of the MacOS packages: the plugins are installed in
# "/Library/Audio/Plug-Ins/Vamp", each plugin is packaged with pkgbuild and
# the bundle installer is generated with productbuild (the plugins can be
# selected at the installation). The binaries are signed with the Developer ID
# Application certificate and the installers are signed with the Developer ID
# Installer certificate, notarized with notarytool, stapled and verified with
# spctl.
message(STATUS "Preparing MacOS package")

set(OS_NAME "MacOS")
set(JOB_NAME "Build::MacOS")
set(WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/MacOS")
file(REMOVE_RECURSE "${WORKING_DIRECTORY}")
file(MAKE_DIRECTORY "${WORKING_DIRECTORY}")
set(TEMP_DIRECTORY "${WORKING_DIRECTORY}/Temp")

pvp_write_about_header("${WORKING_DIRECTORY}")

set(XML_1 "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
string(APPEND XML_1 "<installer-gui-script minSpecVersion=\"1\">\n")
string(APPEND XML_1 "    <title>${PVP_NAME} v${PVP_BUILD_TAG}</title>\n")
string(APPEND XML_1 "    <readme file=\"${WORKING_DIRECTORY}/About.txt\"/>\n")
string(APPEND XML_1 "    <background file=\"${PVP_RESOURCE_DIR}/ircam-logo-noir-rs.png\"/>\n")
string(APPEND XML_1 "    <background alignment=\"bottomleft\"/>\n")
string(APPEND XML_1 "    <options require-scripts=\"false\" customize=\"always\" hostArchitectures=\"x86_64,arm64\" rootVolumeOnly=\"true\"/>\n")
set(XML_2 "    <choices-outline>\n")
set(XML_3 "    </choices-outline>\n")

# Sign all the files of a directory (including the binaries and the nested
# bundles). The codesign calls fail silently for the files that are not
# binaries (e.g. the models or the cat files), therefore the libraries and
# the bundles are verified afterwards: a binary that is not correctly signed
# with the Developer ID certificate would be rejected by the notarization
# service (e.g. when the keychain is locked or unavailable).
function(pvp_sign_directory directory)
  file(GLOB_RECURSE DIR_FILE_PATHS "${directory}/*")
  foreach(FILE_PATH ${DIR_FILE_PATHS})
    if(NOT FILE_PATH MATCHES "_CodeSignature")
      execute_process(COMMAND codesign --sign "${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT}" --entitlements "${PVP_RESOURCE_DIR}/partiels-vamp-plugins.entitlements" -f -o runtime --timestamp "${FILE_PATH}" OUTPUT_QUIET ERROR_QUIET)
    endif()
  endforeach()
  file(GLOB DIR_BUNDLE_PATHS "${directory}/*.vamp")
  foreach(DIR_BUNDLE_PATH ${DIR_BUNDLE_PATHS})
    execute_process(COMMAND codesign --sign "${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT}" --entitlements "${PVP_RESOURCE_DIR}/partiels-vamp-plugins.entitlements" -f -o runtime --timestamp "${DIR_BUNDLE_PATH}" OUTPUT_QUIET)
  endforeach()
  file(GLOB DIR_LIBRARY_PATHS "${directory}/*.dylib")
  foreach(SIGNED_PATH ${DIR_LIBRARY_PATHS} ${DIR_BUNDLE_PATHS})
    execute_process(COMMAND codesign --verify --deep --strict "${SIGNED_PATH}" RESULT_VARIABLE VERIFY_RESULT OUTPUT_QUIET ERROR_QUIET)
    execute_process(COMMAND codesign -dvv "${SIGNED_PATH}" ERROR_VARIABLE DISPLAY_RESULT OUTPUT_QUIET)
    string(FIND "${DISPLAY_RESULT}" "Authority=${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT}" AUTHORITY_POSITION)
    if(NOT VERIFY_RESULT EQUAL 0 OR AUTHORITY_POSITION EQUAL -1)
      message(FATAL_ERROR "Failed to sign ${SIGNED_PATH} with the ${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT} certificate (is the keychain unlocked?).")
    endif()
  endforeach()
endfunction()

function(pvp_finalize_plugin plugin_name plugin_version)
  pvp_append_about(${plugin_name} ${plugin_version} "${WORKING_DIRECTORY}/About.txt")
  pvp_extract_bundle("${plugin_name}" "${OS_NAME}" "${TEMP_DIRECTORY}" BUNDLE_NAME)

  # The package root directory only contains the files to install
  # (the legacy library + cat files or the .vamp bundle).
  set(PACKAGE_ROOT_DIRECTORY "${WORKING_DIRECTORY}/${plugin_name}")
  file(REMOVE_RECURSE "${PACKAGE_ROOT_DIRECTORY}")
  file(MAKE_DIRECTORY "${PACKAGE_ROOT_DIRECTORY}")
  if(NOT BUNDLE_NAME STREQUAL "")
    file(COPY "${TEMP_DIRECTORY}/${BUNDLE_NAME}" DESTINATION "${PACKAGE_ROOT_DIRECTORY}")
  else()
    file(GLOB PAYLOAD_FILE_PATHS "${TEMP_DIRECTORY}/*.dylib" "${TEMP_DIRECTORY}/*.cat")
    file(COPY ${PAYLOAD_FILE_PATHS} DESTINATION "${PACKAGE_ROOT_DIRECTORY}")
  endif()
  file(REMOVE_RECURSE "${TEMP_DIRECTORY}")

  string(TOLOWER "com.ircam.${plugin_name}.vamp.pkg" PACKAGE_UID)
  set(XML_1 "${XML_1}    <pkg-ref id=\"${PACKAGE_UID}\"/>\n" PARENT_SCOPE)
  set(XML_2 "${XML_2}        <line choice=\"${PACKAGE_UID}\"/>\n" PARENT_SCOPE)

  # The choice of a plugin is only proposed and selected if the machine
  # and the operating system of the user match the requirements of the plugin:
  # the minimum macOS version of the plugin and, for the plugins based on deep
  # learning models, the Apple Silicon architecture.
  # The condition is also used by the installation check of the installer of
  # the plugin (see below). The architecture is checked with sysctl, which,
  # unlike system.run, does not require the allow-external-scripts option.
  set(CHOICE_CONDITION "system.compareVersions(system.version.ProductVersion, '${${plugin_name}_MIN_OS}') >= 0")
  if(${plugin_name} IN_LIST PVP_APPLE_SILICON_ONLY_PLUGINS)
    set(CHOICE_CONDITION "(system.sysctl('hw.optional.arm64') == 1) && ${CHOICE_CONDITION}")
  endif()
  set(${plugin_name}_CHOICE_CONDITION "${CHOICE_CONDITION}" PARENT_SCOPE)
  set(${plugin_name}_PLUGIN_VERSION "${plugin_version}" PARENT_SCOPE)
  string(REPLACE "&" "&amp;" CHOICE_CONDITION "${CHOICE_CONDITION}")
  set(XML_3 "${XML_3}    <choice id=\"${PACKAGE_UID}\" visible=\"${CHOICE_CONDITION}\" start_selected=\"${CHOICE_CONDITION}\" title=\"${plugin_name}\"><pkg-ref id=\"${PACKAGE_UID}\"/></choice><pkg-ref id=\"${PACKAGE_UID}\" version=\"${plugin_version}\" onConclusion=\"none\">${plugin_name}.pkg</pkg-ref>\n" PARENT_SCOPE)

  # The preinstall script removes the previous versions of the plugin
  # (the legacy library + cat files and the .vamp bundle).
  set(SCRIPTS_DIRECTORY "${WORKING_DIRECTORY}/Scripts/${plugin_name}")
  file(REMOVE_RECURSE "${SCRIPTS_DIRECTORY}")
  file(MAKE_DIRECTORY "${SCRIPTS_DIRECTORY}")
  set(PREINSTALL_SCRIPT "${SCRIPTS_DIRECTORY}/preinstall")
  file(WRITE "${PREINSTALL_SCRIPT}" "#!/bin/sh\n\n")
  file(APPEND "${PREINSTALL_SCRIPT}" "VAMP_DIRECTORY=\"/Library/Audio/Plug-Ins/Vamp\"\n")
  pvp_get_install_names(${plugin_name} PLUGIN_INSTALL_NAMES)
  foreach(PLUGIN_INSTALL_NAME ${PLUGIN_INSTALL_NAMES})
    file(APPEND "${PREINSTALL_SCRIPT}" "rm -f \"$VAMP_DIRECTORY/${PLUGIN_INSTALL_NAME}.dylib\"\n")
    file(APPEND "${PREINSTALL_SCRIPT}" "rm -f \"$VAMP_DIRECTORY/${PLUGIN_INSTALL_NAME}.cat\"\n")
    file(APPEND "${PREINSTALL_SCRIPT}" "rm -rf \"$VAMP_DIRECTORY/${PLUGIN_INSTALL_NAME}.vamp\"\n")
  endforeach()
  # The models of the previous versions of the plugins were installed outside
  # of the Vamp directory (e.g. the VAX and Whisper models), they are removed.
  pvp_get_legacy_models_commands(${plugin_name} "/Library/Application Support/Ircam" PLUGIN_LEGACY_MODELS_COMMANDS)
  string(REPLACE "    " "" PLUGIN_LEGACY_MODELS_COMMANDS "${PLUGIN_LEGACY_MODELS_COMMANDS}")
  file(APPEND "${PREINSTALL_SCRIPT}" "${PLUGIN_LEGACY_MODELS_COMMANDS}")
  file(APPEND "${PREINSTALL_SCRIPT}" "\nexit 0\n")
  file(CHMOD "${PREINSTALL_SCRIPT}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)

  if(PVP_NOTARIZE)
    pvp_sign_directory("${PACKAGE_ROOT_DIRECTORY}")
    execute_process(COMMAND pkgbuild --sign "${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT}" --timestamp --scripts "${SCRIPTS_DIRECTORY}" --root "${PACKAGE_ROOT_DIRECTORY}" --identifier "${PACKAGE_UID}" --version "${plugin_version}" --install-location "/Library/Audio/Plug-Ins/Vamp/" "${WORKING_DIRECTORY}/${plugin_name}.pkg" OUTPUT_QUIET RESULT_VARIABLE PKGBUILD_RESULT)
    if(NOT PKGBUILD_RESULT EQUAL 0)
      message(FATAL_ERROR "The generation of the ${plugin_name} package failed (pkgbuild error code ${PKGBUILD_RESULT}).")
    endif()
    execute_process(COMMAND pkgutil --check-signature "${WORKING_DIRECTORY}/${plugin_name}.pkg" RESULT_VARIABLE PKGUTIL_RESULT)
    if(NOT PKGUTIL_RESULT EQUAL 0)
      message(FATAL_ERROR "The signature of the ${plugin_name} package is not valid.")
    endif()
  else()
    execute_process(COMMAND pkgbuild --scripts "${SCRIPTS_DIRECTORY}" --root "${PACKAGE_ROOT_DIRECTORY}" --identifier "${PACKAGE_UID}" --version "${plugin_version}" --install-location "/Library/Audio/Plug-Ins/Vamp/" "${WORKING_DIRECTORY}/${plugin_name}.pkg" OUTPUT_QUIET RESULT_VARIABLE PKGBUILD_RESULT)
    if(NOT PKGBUILD_RESULT EQUAL 0)
      message(FATAL_ERROR "The generation of the ${plugin_name} package failed (pkgbuild error code ${PKGBUILD_RESULT}).")
    endif()
  endif()

  list(APPEND PVP_PLUGINS ${plugin_name})
  set(PVP_PLUGINS "${PVP_PLUGINS}" PARENT_SCOPE)
endfunction()

pvp_prepare_plugins()

# Notarize, staple and verify an installer package. The generation fails if
# the notarization is rejected (the log of the notarization service is
# printed to help finding the cause of the rejection).
# The stapling is retried several times because it sometimes fails with a
# transient network error (the stapler error 68 with a NSURLErrorDomain
# -1005 "The network connection was lost" message) even though the
# notarization has been accepted.
macro(pvp_staple_installer installer_path)
  set(STAPLER_RESULT -1)
  foreach(STAPLER_ATTEMPT RANGE 1 4)
    execute_process(COMMAND xcrun stapler staple "${installer_path}" RESULT_VARIABLE STAPLER_RESULT)
    if(STAPLER_RESULT EQUAL 0)
      break()
    endif()
    if(STAPLER_ATTEMPT LESS 4)
      message(WARNING "The stapling of ${installer_path} failed (attempt ${STAPLER_ATTEMPT}, stapler error code ${STAPLER_RESULT}), retrying in 15 seconds...")
      execute_process(COMMAND sleep 15)
    endif()
  endforeach()
  if(NOT STAPLER_RESULT EQUAL 0)
    message(FATAL_ERROR "The stapling of ${installer_path} failed (stapler error code ${STAPLER_RESULT}).")
  endif()
endmacro()

macro(pvp_notarize_installer installer_path)
  execute_process(COMMAND xcrun notarytool submit "${installer_path}" --keychain-profile "${PVP_CODESIGN_APPLE_KEYCHAIN_PROFILE_INSTALLER}" --wait OUTPUT_VARIABLE SUBMIT_RESULT ECHO_OUTPUT_VARIABLE)
  string(FIND "${SUBMIT_RESULT}" "status: Accepted" SUBMIT_ACCEPTED_POSITION)
  if(NOT SUBMIT_ACCEPTED_POSITION EQUAL -1)
    pvp_staple_installer("${installer_path}")
    execute_process(COMMAND spctl -a -vvv -t install "${installer_path}" RESULT_VARIABLE SPCTL_RESULT)
    if(NOT SPCTL_RESULT EQUAL 0)
      message(FATAL_ERROR "The verification of ${installer_path} with the Gatekeeper failed (spctl error code ${SPCTL_RESULT}).")
    endif()
  else()
    string(FIND "${SUBMIT_RESULT}" "id: " SUBMIT_ID_POSITION)
    if(NOT SUBMIT_ID_POSITION EQUAL -1)
      math(EXPR SUBMIT_ID_POSITION "${SUBMIT_ID_POSITION}+4")
      string(SUBSTRING "${SUBMIT_RESULT}" ${SUBMIT_ID_POSITION} 36 SUBMIT_LOG_ID)
      execute_process(COMMAND xcrun notarytool log "${SUBMIT_LOG_ID}" --keychain-profile "${PVP_CODESIGN_APPLE_KEYCHAIN_PROFILE_INSTALLER}")
    endif()
    message(FATAL_ERROR "The notarization of ${installer_path} failed:\n${SUBMIT_RESULT}")
  endif()
endmacro()

file(WRITE "${WORKING_DIRECTORY}/distribution.xml" "${XML_1}${XML_2}${XML_3}</installer-gui-script>\n")

set(INSTALLER_PATH "${WORKING_DIRECTORY}/${PVP_NAME}.pkg")
if(PVP_NOTARIZE)
  execute_process(COMMAND productbuild --sign "${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT}" --timestamp --distribution "${WORKING_DIRECTORY}/distribution.xml" --package-path "${WORKING_DIRECTORY}" "${INSTALLER_PATH}" RESULT_VARIABLE PRODUCTBUILD_RESULT)
  if(NOT PRODUCTBUILD_RESULT EQUAL 0)
    message(FATAL_ERROR "The generation of the MacOS installer failed (productbuild error code ${PRODUCTBUILD_RESULT}).")
  endif()
  pvp_notarize_installer("${INSTALLER_PATH}")
else()
  execute_process(COMMAND productbuild --distribution "${WORKING_DIRECTORY}/distribution.xml" --package-path "${WORKING_DIRECTORY}" "${INSTALLER_PATH}" OUTPUT_QUIET RESULT_VARIABLE PRODUCTBUILD_RESULT)
  if(NOT PRODUCTBUILD_RESULT EQUAL 0)
    message(FATAL_ERROR "The generation of the MacOS installer failed (productbuild error code ${PRODUCTBUILD_RESULT}).")
  endif()
endif()

file(COPY "${INSTALLER_PATH}" DESTINATION "${PVP_OUTPUT_DIRECTORY}")

# Generate one installer per plugin. The plugin package (built with
# pkgbuild) is wrapped in a product archive with its own distribution so
# that the installation is refused if the machine and the operating system
# of the user do not match the requirements of the plugin (see the choice
# conditions of the bundle installer). The installers are notarized (if
# requested) and copied in the package directory of the repository next to
# the bundle installer.
if(PVP_GENERATE_PLUGIN_INSTALLERS)
  set(PLUGIN_INSTALLERS_DIRECTORY "${WORKING_DIRECTORY}/Plugins")
  file(REMOVE_RECURSE "${PLUGIN_INSTALLERS_DIRECTORY}")
  file(MAKE_DIRECTORY "${PLUGIN_INSTALLERS_DIRECTORY}")
  foreach(PLUGIN_NAME ${PVP_PLUGINS})
    string(TOLOWER "com.ircam.${PLUGIN_NAME}.vamp.pkg" PACKAGE_UID)
    set(PLUGIN_DISTRIBUTION_PATH "${WORKING_DIRECTORY}/distribution-${PLUGIN_NAME}.xml")
    set(PLUGIN_XML "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n")
    string(APPEND PLUGIN_XML "<installer-gui-script minSpecVersion=\"1\">\n")
    string(APPEND PLUGIN_XML "    <title>${PVP_NAME} ${PLUGIN_NAME} v${${PLUGIN_NAME}_PLUGIN_VERSION}</title>\n")
    string(APPEND PLUGIN_XML "    <background file=\"${PVP_RESOURCE_DIR}/ircam-logo-noir-rs.png\"/>\n")
    string(APPEND PLUGIN_XML "    <background alignment=\"bottomleft\"/>\n")
    string(APPEND PLUGIN_XML "    <options customize=\"never\" hostArchitectures=\"x86_64,arm64\" rootVolumeOnly=\"true\"/>\n")
    string(APPEND PLUGIN_XML "    <installation-check script=\"pvp_installation_check()\"/>\n")
    string(APPEND PLUGIN_XML "    <script><![CDATA[\n")
    string(APPEND PLUGIN_XML "    function pvp_installation_check() {\n")
    string(APPEND PLUGIN_XML "        if (${${PLUGIN_NAME}_CHOICE_CONDITION}) {\n")
    string(APPEND PLUGIN_XML "            return true;\n")
    string(APPEND PLUGIN_XML "        }\n")
    string(APPEND PLUGIN_XML "        my.result.type = 'Fatal';\n")
    string(APPEND PLUGIN_XML "        my.result.title = '${PLUGIN_NAME} cannot be installed';\n")
    if(${PLUGIN_NAME} IN_LIST PVP_APPLE_SILICON_ONLY_PLUGINS)
      string(APPEND PLUGIN_XML "        my.result.message = '${PLUGIN_NAME} requires a Mac with Apple Silicon and macOS ${${PLUGIN_NAME}_MIN_OS} or later.';\n")
    else()
      string(APPEND PLUGIN_XML "        my.result.message = '${PLUGIN_NAME} requires macOS ${${PLUGIN_NAME}_MIN_OS} or later.';\n")
    endif()
    string(APPEND PLUGIN_XML "        return false;\n")
    string(APPEND PLUGIN_XML "    }\n")
    string(APPEND PLUGIN_XML "    ]]></script>\n")
    string(APPEND PLUGIN_XML "    <choices-outline>\n")
    string(APPEND PLUGIN_XML "        <line choice=\"${PACKAGE_UID}\"/>\n")
    string(APPEND PLUGIN_XML "    </choices-outline>\n")
    string(APPEND PLUGIN_XML "    <choice id=\"${PACKAGE_UID}\" title=\"${PLUGIN_NAME}\"><pkg-ref id=\"${PACKAGE_UID}\"/></choice><pkg-ref id=\"${PACKAGE_UID}\" version=\"${${PLUGIN_NAME}_PLUGIN_VERSION}\" onConclusion=\"none\">${PLUGIN_NAME}.pkg</pkg-ref>\n")
    string(APPEND PLUGIN_XML "</installer-gui-script>\n")
    file(WRITE "${PLUGIN_DISTRIBUTION_PATH}" "${PLUGIN_XML}")

    set(PLUGIN_INSTALLER_PATH "${PLUGIN_INSTALLERS_DIRECTORY}/${PLUGIN_NAME}.pkg")
    if(PVP_NOTARIZE)
      execute_process(COMMAND productbuild --sign "${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT}" --timestamp --distribution "${PLUGIN_DISTRIBUTION_PATH}" --package-path "${WORKING_DIRECTORY}" "${PLUGIN_INSTALLER_PATH}" OUTPUT_QUIET RESULT_VARIABLE PRODUCTBUILD_RESULT)
    else()
      execute_process(COMMAND productbuild --distribution "${PLUGIN_DISTRIBUTION_PATH}" --package-path "${WORKING_DIRECTORY}" "${PLUGIN_INSTALLER_PATH}" OUTPUT_QUIET RESULT_VARIABLE PRODUCTBUILD_RESULT)
    endif()
    if(NOT PRODUCTBUILD_RESULT EQUAL 0)
      message(FATAL_ERROR "The generation of the installer of ${PLUGIN_NAME} failed (productbuild error code ${PRODUCTBUILD_RESULT}).")
    endif()
    if(PVP_NOTARIZE)
      pvp_notarize_installer("${PLUGIN_INSTALLER_PATH}")
    endif()
    file(COPY "${PLUGIN_INSTALLER_PATH}" DESTINATION "${PVP_OUTPUT_DIRECTORY}")
  endforeach()
endif()

# The Uninstall.sh script is assembled from the resource/macos-uninstall.sh.in
# template and the uninstallation blocks of all the plugins: it removes the
# files of the plugins from the Vamp directory of the system (the script must
# be run with sudo) and forgets the receipts of their packages.
string(REPLACE ";" " " PVP_PLUGINS_STRING "${PVP_ALL_PLUGINS}")
set(PVP_VAMP_DIRECTORY "/Library/Audio/Plug-Ins/Vamp")
set(PVP_UNINSTALL_BLOCKS "")
foreach(PLUGIN_NAME ${PVP_ALL_PLUGINS})
  pvp_get_install_names("${PLUGIN_NAME}" PLUGIN_INSTALL_NAMES)
  list(GET PLUGIN_INSTALL_NAMES 1 PVP_PLUGIN_ALT_NAME)
  string(TOLOWER "com.ircam.${PLUGIN_NAME}.vamp.pkg" PVP_PLUGIN_UID)
  pvp_get_legacy_models_commands("${PLUGIN_NAME}" "/Library/Application Support/Ircam" PVP_PLUGIN_LEGACY_MODELS_COMMANDS)
  set(PLUGIN_NAME "${PLUGIN_NAME}")
  configure_file("${PVP_RESOURCE_DIR}/macos-uninstall-block.sh.in" "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh" @ONLY)
  file(READ "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh" PLUGIN_UNINSTALL_BLOCK)
  file(REMOVE "${CMAKE_CURRENT_BINARY_DIR}/UninstallBlock.sh")
  string(APPEND PVP_UNINSTALL_BLOCKS "${PLUGIN_UNINSTALL_BLOCK}")
endforeach()
configure_file("${PVP_RESOURCE_DIR}/macos-uninstall.sh.in" "${PVP_OUTPUT_DIRECTORY}/Uninstall.sh" @ONLY)
file(CHMOD "${PVP_OUTPUT_DIRECTORY}/Uninstall.sh" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
