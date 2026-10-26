# The configuration of the generation: the name and the version of the
# package, the options, the signing certificates and the private token.
set(PVP_NAME "Partiels Vamp Plugins")
set(PVP_RESOURCE_DIR "${PVP_ROOT_DIR}/resource")
set(PVP_BUILD_TAG "" CACHE STRING "The current tag build")
if(PVP_BUILD_TAG STREQUAL "")
set(PVP_BUILD_TAG "1.0.0")
endif()
message(STATUS "PVP: " ${PVP_BUILD_TAG})

# The installers are collected in a dedicated directory that is published as
# an artifact by the continuous integration (never inside the source tree).
# Note that the directory is never wiped entirely: several generations (e.g.
# the packages and the manuals on the Linux runner of the continuous
# integration) can be chained in the same job.
set(PVP_OUTPUT_DIRECTORY "${PVP_ROOT_DIR}/package")
file(MAKE_DIRECTORY "${PVP_OUTPUT_DIRECTORY}")
set(PVP_CACHE_DIRECTORY "" CACHE PATH "The directory used to cache the downloaded plugins (empty to disable)")

option(PVP_GENERATE_MANUALS "Generate the manuals package" OFF)
option(PVP_GENERATE_LINUX "Generate the linux package" OFF)
option(PVP_GENERATE_PLUGIN_INSTALLERS "Generate one installer per plugin" ON)

set(PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT "Developer ID Application" CACHE STRING "The Apple Developer ID Application certificate")
set(PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT "Developer ID Installer" CACHE STRING "The Apple Developer ID Installer certificate")
set(PVP_CODESIGN_APPLE_KEYCHAIN_PROFILE_INSTALLER "notary-installer" CACHE STRING "The Apple keychain profile for installer")

# Retrieve the private token (the PRIVATE_TOKEN variable can be passed on
# the command line, the FORGE_PRIVATE_TOKEN environment variable can be
# used on the continuous integration, otherwise on macOS the token is
# retrieved from the keychain). The token is only required to download the
# plugins hosted on the Ircam Forge 2: the generation fails when a plugin
# has to be downloaded without token (see cmake/download.cmake).
if(NOT DEFINED PRIVATE_TOKEN AND DEFINED ENV{FORGE_PRIVATE_TOKEN})
set(PRIVATE_TOKEN "$ENV{FORGE_PRIVATE_TOKEN}")
endif()
if(NOT DEFINED PRIVATE_TOKEN)
if(APPLE)
  message(STATUS "Get private token from keychain")
  execute_process(COMMAND "security" "find-generic-password" "-s" "Forge2 Ircam Token" "-w" OUTPUT_VARIABLE PRIVATE_TOKEN ERROR_VARIABLE PRIVATE_TOKEN_ERROR)
  if(PRIVATE_TOKEN_ERROR)
    message(WARNING "Ircam Forge2 Token cannot be retrieved: " "${PRIVATE_TOKEN_ERROR}")
    set(PRIVATE_TOKEN "")
  endif()
else()
  message(WARNING "PRIVATE_TOKEN undefined: the plugins hosted on the Ircam Forge 2 cannot be downloaded.")
  set(PRIVATE_TOKEN "")
endif()
endif()

# Check if the notarization can be performed: both certificates are
# required, the second check can only disable the notarization.
if(APPLE AND NOT PVP_GENERATE_LINUX)
execute_process(COMMAND security find-certificate -c "${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT}" OUTPUT_VARIABLE CERTIFICATE_RESULT ERROR_VARIABLE CERTIFICATE_ERROR)
if(CERTIFICATE_RESULT)
  message(STATUS "Apple notarization with ${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT} certificate is available")
  set(PVP_NOTARIZE ON)
else()
  message(WARNING "Apple notarization with ${PVP_CODESIGN_APPLE_DEV_ID_APPLICATION_CERT} certificate is not available")
  set(PVP_NOTARIZE OFF)
endif()
execute_process(COMMAND security find-certificate -c "${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT}" OUTPUT_VARIABLE CERTIFICATE_RESULT ERROR_VARIABLE CERTIFICATE_ERROR)
if(CERTIFICATE_RESULT)
  message(STATUS "Apple notarization with ${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT} certificate is available")
else()
  message(WARNING "Apple notarization with ${PVP_CODESIGN_APPLE_DEV_ID_INSTALLER_CERT} certificate is not available")
  set(PVP_NOTARIZE OFF)
endif()
endif()
