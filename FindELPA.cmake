# .rst: FindELPA
# --------
#
# Find the ELPA eigenvalue solver library. Searches for elpa_openmp when OpenMP
# is enabled.
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

# When ROOT is explicit, don't fall back to system paths (avoids finding a
# system ELPA header without matching Fortran modules).
if(_ELPA_PATHS)
  set(_ELPA_NO_DEFAULT NO_DEFAULT_PATH)
endif()

find_path(
  ELPA_INCLUDE_DIR
  NAMES elpa/elpa.h
  HINTS ${_ELPA_PATHS}
  PATH_SUFFIXES "include" "include/elpa" ${_ELPA_NO_DEFAULT})

# spack module dir pattern: include/{elpa|elpa_openmp}-{VER}/modules/
if(ELPA_INCLUDE_DIR)
  file(GLOB _ELPA_MOD "${ELPA_INCLUDE_DIR}/elpa*/modules"
       "${ELPA_INCLUDE_DIR}/elpa_*")
  if(_ELPA_MOD)
    list(APPEND ELPA_INCLUDE_DIR ${_ELPA_MOD})
    list(REMOVE_DUPLICATES ELPA_INCLUDE_DIR)
  endif()
endif()

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
