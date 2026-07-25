# .rst: FindLIBMBD
# ----------
#
# Find the libMBD library (many-body dispersion).
#
# Strategy: 1. Config-first: find_package(Mbd CONFIG) — uses MbdConfig.cmake
# (note: upstream installs to lib/cmake/mbd/ with MbdConfig.cmake) 2. Manual
# fallback: find_library + find_path
#
# Imported target::
#
# LIBMBD::libmbd  (wraps Mbd::mbd from config, or creates UNKNOWN IMPORTED)

set(_LIBMBD_PATHS)
foreach(_v LIBMBD_ROOT LibMBD_ROOT)
  if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
    list(APPEND _LIBMBD_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}} AND NOT "$ENV{${_v}}" STREQUAL "")
    list(APPEND _LIBMBD_PATHS "$ENV{${_v}}")
  endif()
endforeach()

# --- 1) Config package (preferred) ---
# libMBD installs MbdConfig.cmake in lib/cmake/mbd/ (lowercase dir, uppercase
# file). find_package(Mbd) can't auto-discover this due to the case mismatch, so
# we locate the config file manually and include it directly.
set(_mbd_config "")
foreach(_path IN LISTS _LIBMBD_PATHS)
  if(EXISTS "${_path}/lib/cmake/mbd/MbdConfig.cmake")
    set(_mbd_config "${_path}/lib/cmake/mbd/MbdConfig.cmake")
    break()
  endif()
endforeach()
if(_mbd_config)
  include("${_mbd_config}")
endif()

if(TARGET Mbd::mbd OR TARGET Mbd::Mbd)
  if(NOT TARGET LIBMBD::libmbd)
    add_library(LIBMBD::libmbd INTERFACE IMPORTED)
    if(TARGET Mbd::mbd)
      set_property(TARGET LIBMBD::libmbd PROPERTY INTERFACE_LINK_LIBRARIES
                                                  Mbd::mbd)
    elseif(TARGET Mbd::Mbd)
      set_property(TARGET LIBMBD::libmbd PROPERTY INTERFACE_LINK_LIBRARIES
                                                  Mbd::Mbd)
    endif()
  endif()
  set(LIBMBD_FOUND TRUE)
  message(STATUS "Found libMBD (Config): Mbd::mbd -> LIBMBD::libmbd")
  return()
endif()

# --- 2) Manual fallback ---
find_library(
  LIBMBD_LIBRARIES
  NAMES mbd
  HINTS ${_LIBMBD_PATHS}
  PATH_SUFFIXES "build/src" "src" "lib" "lib64")

find_path(
  LIBMBD_INCLUDE_DIRS
  NAMES mbd.h mbd.mod
  HINTS ${_LIBMBD_PATHS}
  PATH_SUFFIXES "build/src/modules" "src" "module" "modules" "include/mbd"
                "include")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  LIBMBD
  REQUIRED_VARS LIBMBD_INCLUDE_DIRS LIBMBD_LIBRARIES
  FAIL_MESSAGE "Set LIBMBD_ROOT to the libMBD installation")

if(LIBMBD_FOUND)
  message(STATUS "Found libMBD (fallback): ${LIBMBD_LIBRARIES}")
  if(NOT TARGET LIBMBD::libmbd)
    add_library(LIBMBD::libmbd UNKNOWN IMPORTED)
    set_target_properties(
      LIBMBD::libmbd
      PROPERTIES IMPORTED_LOCATION "${LIBMBD_LIBRARIES}"
                 INTERFACE_INCLUDE_DIRECTORIES "${LIBMBD_INCLUDE_DIRS}")
  endif()
endif()

mark_as_advanced(LIBMBD_LIBRARIES LIBMBD_INCLUDE_DIRS)
