# .rst: FindELPA
# --------
#
# Find the ELPA eigenvalue solver library. Searches for elpa_openmp when OpenMP
# is enabled.
#
# Supports two layouts: 1. Standard: include/elpa/elpa.h 2. Spack/versioned:
# include/elpa[_openmp]-{VER}/elpa/elpa.h with modules in
# include/elpa[_openmp]-{VER}/modules/
#
# Imported target::
#
# ELPA::ELPA

set(_ELPA_PATHS)
foreach(_v ELPA_ROOT Elpa_ROOT)
  if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
    list(APPEND _ELPA_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}} AND NOT "$ENV{${_v}}" STREQUAL "")
    list(APPEND _ELPA_PATHS "$ENV{${_v}}")
  endif()
endforeach()

# When ROOT is explicit, don't fall back to system paths.
if(_ELPA_PATHS)
  set(_ELPA_NO_DEFAULT NO_DEFAULT_PATH)
endif()

# --- locate header ---
# Try standard find_path first, then glob for version-specific layout.
find_path(
  ELPA_INCLUDE_DIR
  NAMES elpa/elpa.h
  HINTS ${_ELPA_PATHS}
  PATH_SUFFIXES "include" "include/elpa" ${_ELPA_NO_DEFAULT})

# Spack layout: include/elpa[_openmp]-{VER}/elpa/elpa.h
if(NOT ELPA_INCLUDE_DIR)
  foreach(_path IN LISTS _ELPA_PATHS)
    file(GLOB _elpa_ver_dirs "${_path}/include/elpa*")
    foreach(_vd ${_elpa_ver_dirs})
      if(EXISTS "${_vd}/elpa/elpa.h")
        set(ELPA_INCLUDE_DIR "${_vd}")
        break()
      endif()
    endforeach()
    if(ELPA_INCLUDE_DIR)
      break()
    endif()
  endforeach()
endif()

# Append modules subdir: elpa*/modules/
if(ELPA_INCLUDE_DIR)
  file(GLOB _ELPA_MOD "${ELPA_INCLUDE_DIR}/modules"
       "${ELPA_INCLUDE_DIR}/elpa*/modules")
  if(_ELPA_MOD)
    list(APPEND ELPA_INCLUDE_DIR ${_ELPA_MOD})
    list(REMOVE_DUPLICATES ELPA_INCLUDE_DIR)
  endif()
endif()

# --- locate library ---
if(VASP_OPENMP)
  find_library(
    ELPA_LIBRARIES
    NAMES elpa_openmp elpa
    HINTS ${_ELPA_PATHS}
    PATH_SUFFIXES "lib" "lib64" ${_ELPA_NO_DEFAULT})
else()
  find_library(
    ELPA_LIBRARIES
    NAMES elpa
    HINTS ${_ELPA_PATHS}
    PATH_SUFFIXES "lib" "lib64" ${_ELPA_NO_DEFAULT})
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  ELPA
  REQUIRED_VARS ELPA_INCLUDE_DIR ELPA_LIBRARIES
  FAIL_MESSAGE "Set ELPA_ROOT to the ELPA installation (>= 2021)")

if(ELPA_FOUND)
  if(NOT ELPA_MESSAGE_SHOWN)
    message(STATUS "Found ELPA: ${ELPA_LIBRARIES}")
    message(STATUS "  ELPA include: ${ELPA_INCLUDE_DIR}")
  endif()
  set(ELPA_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET ELPA::ELPA)
    add_library(ELPA::ELPA UNKNOWN IMPORTED)
    set_target_properties(
      ELPA::ELPA
      PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                 IMPORTED_LOCATION "${ELPA_LIBRARIES}"
                 INTERFACE_INCLUDE_DIRECTORIES "${ELPA_INCLUDE_DIR}")
  endif()
endif()

mark_as_advanced(ELPA_LIBRARIES ELPA_INCLUDE_DIR)
