# The properties of the plugins (name, GitLab project id or GitHub repository,
# branch or tag, description, minimum macOS version and supported
# architectures) are defined in the resource/plugins.json file. The plugins
# hosted on the Ircam Forge 2 are retrieved with the version of their ref
# (a branch or a tag); the plugins hosted on GitHub are retrieved from their
# releases (the ref is a release tag, or "latest" to use the most recent one).
# The variables are named after the plugins:
#  - ${<PLUGIN>_REF}: the branch or tag of the plugin (e.g. ${SUPERVP_REF}),
#    which can be overridden on the command line (e.g. -DSUPERVP_REF=7.0.1),
#  - ${<Plugin>_GITLAB_ID}: the project id on the Ircam Forge 2 (if any),
#  - ${<Plugin>_REPOSITORY}: the GitHub repository of the plugin (if any),
#  - ${<Plugin>_DESCRIPTION}: the description used in the About file,
#  - ${<Plugin>_MIN_OS}: the minimum macOS version of the plugin,
#  - ${<Plugin>_ARCHITECTURES}: the macOS architectures supported by the plugin,
#  - ${<Plugin>_MANUALS}: the plugin has a manual (if any).
# The metadata used by the plugin manager of Partiels (the identifier, the
# maker and the features of each plugin) are defined in the plugins.json
# file and used by generate-plugin-list.cmake to generate the plugin list.
# The plugins are listed in the PVP_ALL_PLUGINS list (in the order of the
# json file, which is the order of the packages and of the About file) and
# the plugins that only support the Apple Silicon machines are collected in
# the PVP_APPLE_SILICON_ONLY_PLUGINS list.
macro(pvp_read_plugins)
file(READ "${PVP_RESOURCE_DIR}/plugins.json" PVP_PLUGINS_JSON)
string(JSON PVP_PLUGINS_COUNT LENGTH "${PVP_PLUGINS_JSON}")
math(EXPR PVP_PLUGINS_LAST "${PVP_PLUGINS_COUNT} - 1")
set(PVP_ALL_PLUGINS "")
set(PVP_APPLE_SILICON_ONLY_PLUGINS "")
foreach(PVP_PLUGIN_INDEX RANGE ${PVP_PLUGINS_LAST})
string(JSON PLUGIN_NAME GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "name")
string(JSON PLUGIN_REF GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "ref")
string(JSON PLUGIN_DESCRIPTION GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "description")
string(JSON PLUGIN_MIN_OS GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "minOs")

string(TOUPPER "${PLUGIN_NAME}" PLUGIN_NAME_UPPER)
set(${PLUGIN_NAME_UPPER}_REF "${PLUGIN_REF}" CACHE STRING "Branch or tag of the ${PLUGIN_NAME} repository")
set(${PLUGIN_NAME}_DESCRIPTION "${PLUGIN_DESCRIPTION}")
set(${PLUGIN_NAME}_MIN_OS "${PLUGIN_MIN_OS}")

string(JSON PLUGIN_GITLAB_ID ERROR_VARIABLE PLUGIN_GITLAB_ID_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "gitlabId")
if(NOT PLUGIN_GITLAB_ID_ERROR)
  set(${PLUGIN_NAME}_GITLAB_ID "${PLUGIN_GITLAB_ID}")
endif()
string(JSON PLUGIN_REPOSITORY ERROR_VARIABLE PLUGIN_REPOSITORY_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "repository")
if(NOT PLUGIN_REPOSITORY_ERROR)
  set(${PLUGIN_NAME}_REPOSITORY "${PLUGIN_REPOSITORY}")
endif()
string(JSON PLUGIN_MANUALS ERROR_VARIABLE PLUGIN_MANUALS_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "manuals")
if(NOT PLUGIN_MANUALS_ERROR)
  set(${PLUGIN_NAME}_MANUALS "${PLUGIN_MANUALS}")
endif()
string(JSON PLUGIN_LEGACY_MODELS ERROR_VARIABLE PLUGIN_LEGACY_MODELS_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "legacyModels")
if(NOT PLUGIN_LEGACY_MODELS_ERROR)
  set(${PLUGIN_NAME}_LEGACY_MODELS "${PLUGIN_LEGACY_MODELS}")
endif()

string(JSON PLUGIN_ARCHITECTURES_COUNT LENGTH "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "architectures")
math(EXPR PLUGIN_ARCHITECTURES_LAST "${PLUGIN_ARCHITECTURES_COUNT} - 1")
set(PLUGIN_ARCHITECTURES "")
foreach(PLUGIN_ARCHITECTURE_INDEX RANGE ${PLUGIN_ARCHITECTURES_LAST})
  string(JSON PLUGIN_ARCHITECTURE GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "architectures" "${PLUGIN_ARCHITECTURE_INDEX}")
  list(APPEND PLUGIN_ARCHITECTURES "${PLUGIN_ARCHITECTURE}")
endforeach()
set(${PLUGIN_NAME}_ARCHITECTURES "${PLUGIN_ARCHITECTURES}")
if(NOT "${PLUGIN_ARCHITECTURES}" MATCHES "x86_64")
  list(APPEND PVP_APPLE_SILICON_ONLY_PLUGINS "${PLUGIN_NAME}")
endif()

list(APPEND PVP_ALL_PLUGINS "${PLUGIN_NAME}")

  # The metadata used by the plugin manager of Partiels: the identifier,
  # the maker and the features (the name and the description of the plugin
  # are shared with the packages).
  string(JSON PLUGIN_IDENTIFIER ERROR_VARIABLE PLUGIN_IDENTIFIER_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "identifier")
  if(PLUGIN_IDENTIFIER_ERROR)
    message(FATAL_ERROR "The identifier of " ${PLUGIN_NAME} " is missing in the resource/plugins.json file.")
  endif()
  set(${PLUGIN_NAME}_IDENTIFIER "${PLUGIN_IDENTIFIER}")
  string(JSON PLUGIN_MAKER ERROR_VARIABLE PLUGIN_MAKER_ERROR GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "maker")
  if(PLUGIN_MAKER_ERROR)
    set(PLUGIN_MAKER "Ircam")
  endif()
  set(${PLUGIN_NAME}_MAKER "${PLUGIN_MAKER}")
  string(JSON PLUGIN_FEATURES_COUNT LENGTH "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "features")
  math(EXPR PLUGIN_FEATURES_LAST "${PLUGIN_FEATURES_COUNT} - 1")
  set(PLUGIN_FEATURES "")
  foreach(PLUGIN_FEATURE_INDEX RANGE ${PLUGIN_FEATURES_LAST})
    string(JSON PLUGIN_FEATURE GET "${PVP_PLUGINS_JSON}" "${PVP_PLUGIN_INDEX}" "features" "${PLUGIN_FEATURE_INDEX}")
    list(APPEND PLUGIN_FEATURES "${PLUGIN_FEATURE}")
  endforeach()
  set(${PLUGIN_NAME}_FEATURES "${PLUGIN_FEATURES}")

endforeach()
endmacro()
