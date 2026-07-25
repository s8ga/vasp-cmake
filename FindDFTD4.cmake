# .rst: FindDFTD4
# ---------
#
# Find the DFT-D4 dispersion library for VASP.
#
# Strategy: 1. Config-first via find_package(dftd4 CONFIG) 2. Manual fallback:
# find_library for dftd4 + deps
#
# Imported target::
#
# DFTD4::dftd4

set(_DFTD4_PATHS)
set(_DFTD4_PATHS)
foreach(_v DFTD4_ROOT dftd4_ROOT)
  if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
    list(APPEND _DFTD4_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}} AND NOT "$ENV{${_v}}" STREQUAL "")
    list(APPEND _DFTD4_PATHS "$ENV{${_v}}")
  endif()
endforeach()

# --- 1) Config package (preferred; pulls transitive deps) ---
set(_save "${CMAKE_PREFIX_PATH}")
if(_DFTD4_PATHS)
  list(PREPEND CMAKE_PREFIX_PATH ${_DFTD4_PATHS})
endif()
find_package(dftd4 ${DFTD4_FIND_VERSION} CONFIG QUIET)
set(CMAKE_PREFIX_PATH "${_save}")
unset(_save)

if(dftd4_FOUND)
  if(NOT TARGET DFTD4::dftd4)
    if(TARGET dftd4::dftd4)
      add_library(DFTD4::dftd4 INTERFACE IMPORTED)
      set_property(TARGET DFTD4::dftd4 PROPERTY INTERFACE_LINK_LIBRARIES
                                                dftd4::dftd4)
    else()
      message(FATAL_ERROR "dftd4 config found but target missing")
    endif()
  endif()
  set(DFTD4_FOUND TRUE)
  message(STATUS "Found DFTD4 (Config): dftd4::dftd4")
  return()
endif()

# --- 2) Manual fallback ---
find_library(
  DFTD4_LIBRARY
  NAMES dftd4
  HINTS ${_DFTD4_PATHS}
  PATH_SUFFIXES lib lib64)
find_library(
  DFTD4_MULTICHARGE_LIBRARY
  NAMES multicharge
  HINTS ${_DFTD4_PATHS}
  PATH_SUFFIXES lib lib64)
find_library(
  DFTD4_MCTC_LIBRARY
  NAMES mctc-lib mctc_lib
  HINTS ${_DFTD4_PATHS}
  PATH_SUFFIXES lib lib64)
find_library(
  DFTD4_MSTORE_LIBRARY
  NAMES mstore
  HINTS ${_DFTD4_PATHS}
  PATH_SUFFIXES lib lib64)

# Module dirs: include/dftd4/{COMPILER}-{VER}/
find_path(
  DFTD4_INCLUDE_DIR
  NAMES dftd4.h dftd4.mod dftd4_api.mod
  HINTS ${_DFTD4_PATHS}
  PATH_SUFFIXES include include/dftd4 module modules)

set(DFTD4_DEP_LIBRARIES)
foreach(_dep DFTD4_MULTICHARGE_LIBRARY DFTD4_MCTC_LIBRARY DFTD4_MSTORE_LIBRARY)
  if(${_dep})
    list(APPEND DFTD4_DEP_LIBRARIES ${${_dep}})
  endif()
endforeach()
set(DFTD4_LIBRARIES ${DFTD4_LIBRARY} ${DFTD4_DEP_LIBRARIES})

# Detect Fortran module subdirectory: include/dftd4/{COMPILER}-{VER}/
set(_DFTD4_MOD_DIR "")
if(DFTD4_INCLUDE_DIR)
  file(GLOB _dftd4_mods "${DFTD4_INCLUDE_DIR}/dftd4/*-*"
       "${DFTD4_INCLUDE_DIR}/dftd4")
  foreach(_d ${_dftd4_mods})
    if(IS_DIRECTORY "${_d}")
      if(EXISTS "${_d}/dftd4.mod" OR EXISTS "${_d}/dftd4_utils.mod")
        set(_DFTD4_MOD_DIR "${_d}")
        break()
      endif()
    endif()
  endforeach()
endif()
if(_DFTD4_MOD_DIR)
  list(APPEND DFTD4_INCLUDE_DIR "${_DFTD4_MOD_DIR}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  DFTD4
  REQUIRED_VARS DFTD4_LIBRARY DFTD4_INCLUDE_DIR
  FAIL_MESSAGE "Build DFT-D4 with -DWITH_API_V2=ON and set DFTD4_ROOT")

if(DFTD4_FOUND)
  message(STATUS "Found DFTD4 (fallback): ${DFTD4_LIBRARIES}")
  if(NOT TARGET DFTD4::dftd4)
    add_library(DFTD4::dftd4 UNKNOWN IMPORTED)
    set_target_properties(
      DFTD4::dftd4
      PROPERTIES IMPORTED_LOCATION "${DFTD4_LIBRARY}"
                 INTERFACE_INCLUDE_DIRECTORIES "${DFTD4_INCLUDE_DIR}"
                 INTERFACE_LINK_LIBRARIES "${DFTD4_DEP_LIBRARIES}")
  endif()
endif()

mark_as_advanced(DFTD4_LIBRARY DFTD4_MULTICHARGE_LIBRARY DFTD4_MCTC_LIBRARY
                 DFTD4_MSTORE_LIBRARY DFTD4_INCLUDE_DIR)
