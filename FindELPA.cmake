# .rst: FindELPA
# --------
#
# Find the ELPA eigenvalue solver library.
#
# Strategy: 1. pkg-config (preferred; handles version-specific dirs
# automatically) 2. Manual fallback: find_path (with glob for version-specific
# layout) + find_library
#
# When VASP_OPENMP is ON, prefers elpa_openmp over elpa.
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

# --- 1) pkg-config (preferred) ---
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
  if(_ELPA_PATHS)
    set(_save_pkg "$ENV{PKG_CONFIG_PATH}")
    foreach(_p IN LISTS _ELPA_PATHS)
      if(EXISTS "${_p}/lib/pkgconfig" OR EXISTS "${_p}/lib64/pkgconfig")
        set(ENV{PKG_CONFIG_PATH}
            "${_p}/lib/pkgconfig:${_p}/lib64/pkgconfig:$ENV{PKG_CONFIG_PATH}")
      endif()
    endforeach()
  endif()

  if(VASP_OPENMP)
    pkg_search_module(ELPA QUIET IMPORTED_TARGET GLOBAL elpa_openmp)
  endif()
  if(NOT ELPA_FOUND)
    pkg_search_module(ELPA QUIET IMPORTED_TARGET GLOBAL elpa)
  endif()

  # Restore PKG_CONFIG_PATH
  if(_ELPA_PATHS)
    set(ENV{PKG_CONFIG_PATH} "${_save_pkg}")
  endif()
endif()

if(ELPA_FOUND)
  # pkg-config gives base include dir; append /modules for Fortran .mod files
  set(_elpa_inc_dirs ${ELPA_INCLUDE_DIRS})
  foreach(_d ${ELPA_INCLUDE_DIRS})
    if(IS_DIRECTORY "${_d}/modules")
      list(APPEND _elpa_inc_dirs "${_d}/modules")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _elpa_inc_dirs)

  if(NOT TARGET ELPA::ELPA)
    add_library(ELPA::ELPA INTERFACE IMPORTED)
  endif()
  set_target_properties(
    ELPA::ELPA PROPERTIES INTERFACE_LINK_LIBRARIES "${ELPA_LINK_LIBRARIES}"
                          INTERFACE_INCLUDE_DIRECTORIES "${_elpa_inc_dirs}")
  message(STATUS "Found ELPA (pkg-config): ${ELPA_LINK_LIBRARIES}")
  return()
endif()

# --- 2) Manual fallback ---
if(_ELPA_PATHS)
  set(_ELPA_NO_DEFAULT NO_DEFAULT_PATH)
endif()

# Standard layout: include/elpa/elpa.h
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

# Append modules subdir
if(ELPA_INCLUDE_DIR)
  file(GLOB _ELPA_MOD "${ELPA_INCLUDE_DIR}/modules"
       "${ELPA_INCLUDE_DIR}/elpa*/modules")
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
  message(STATUS "Found ELPA (fallback): ${ELPA_LIBRARIES}")
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
