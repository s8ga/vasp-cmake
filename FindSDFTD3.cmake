# .rst: FindSDFTD3
# ----------
#
# Find the simple-DFT-D3 library. Shares mctc-lib with DFT-D4 (reused if
# DFTD4::dftd4 exists).
#
# Result variables::
#
# SDFTD3_FOUND        - True if found SDFTD3_LIBRARIES    - The libraries
# SDFTD3_INCLUDE_DIRS - Include directories
#
# Imported target::
#
# SDFTD3::sdftd3

set(_SDFTD3_PATHS)
foreach(_v SDFTD3_ROOT)
  if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
    list(APPEND _SDFTD3_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}} AND NOT "$ENV{${_v}}" STREQUAL "")
    list(APPEND _SDFTD3_PATHS "$ENV{${_v}}")
  endif()
endforeach()

find_library(
  SDFTD3_LIBRARY
  NAMES s-dftd3 sdftd3
  HINTS ${_SDFTD3_PATHS}
  PATH_SUFFIXES "lib" "lib64")

# spack module dir: include/s-dftd3/{COMPILER}-{VER}/
find_path(
  SDFTD3_INCLUDE_DIRS
  NAMES s-dftd3.h dftd3.mod
  HINTS ${_SDFTD3_PATHS}
  PATH_SUFFIXES "include" "include/s-dftd3" "module" "modules")

# mctc-lib shared dep: reuse DFTD4's, else search independently
if(NOT TARGET DFTD4::dftd4)
  find_library(
    SDFTD3_MCTC_LIBRARY
    NAMES mctc-lib mctc_lib
    HINTS ${_SDFTD3_PATHS}
    PATH_SUFFIXES "lib" "lib64")
endif()

set(SDFTD3_LIBRARIES ${SDFTD3_LIBRARY})
if(SDFTD3_MCTC_LIBRARY)
  list(APPEND SDFTD3_LIBRARIES ${SDFTD3_MCTC_LIBRARY})
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  SDFTD3
  REQUIRED_VARS SDFTD3_LIBRARY SDFTD3_INCLUDE_DIRS
  FAIL_MESSAGE "Set SDFTD3_ROOT to the simple-DFT-D3 installation")

if(SDFTD3_FOUND)
  if(NOT SDFTD3_MESSAGE_SHOWN)
    message(STATUS "Found simple-DFT-D3: ${SDFTD3_LIBRARIES}")
  endif()
  set(SDFTD3_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET SDFTD3::sdftd3)
    add_library(SDFTD3::sdftd3 UNKNOWN IMPORTED)
    set_target_properties(
      SDFTD3::sdftd3
      PROPERTIES IMPORTED_LOCATION "${SDFTD3_LIBRARY}"
                 INTERFACE_INCLUDE_DIRECTORIES "${SDFTD3_INCLUDE_DIRS}")
    if(SDFTD3_MCTC_LIBRARY)
      set_property(
        TARGET SDFTD3::sdftd3
        APPEND
        PROPERTY INTERFACE_LINK_LIBRARIES ${SDFTD3_MCTC_LIBRARY})
    endif()
  endif()
endif()

mark_as_advanced(SDFTD3_FOUND SDFTD3_LIBRARY SDFTD3_MCTC_LIBRARY
                 SDFTD3_INCLUDE_DIRS)
