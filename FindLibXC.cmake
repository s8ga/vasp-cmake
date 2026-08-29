# .rst: FindLibXC
# -----------
#
# Find the LibXC library (exchange-correlation functionals).
#
# Supports modern LibXC (5+/6+/7+) with Fortran 2003 interface (xcf03 /
# xc_f03_*.mod) and legacy LibXC with Fortran 90 interface (xcf90 /
# xc_f90_*.mod).
#
# Result variables::
#
# LibXC_FOUND              - True if libxc is found LibXC_LIBRARIES          - C
# library (libxc) LibXC_FORTRAN_LIBRARIES  - Fortran library (libxcf03 or
# libxcf90) LibXC_INCLUDE_DIRS       - C + Fortran include directories
#
# Imported target::
#
# LibXC::libxc

# Collect ROOT hints (always, regardless of CMP0074/CMP0144)
include(vasp_find_utils)

vasp_pkg_root(_LibXC_PATHS LibXC LIBXC EXTRA_VARS Libxc_ROOT Libxc_DIR)

# --- C library (always required) ---
find_library(
  LibXC_LIBRARIES
  NAMES xc
  HINTS ${_LibXC_PATHS}
  PATH_SUFFIXES "libxc/lib" "libxc/lib64" "libxc" "lib" "lib64")

# --- Fortran library: prefer f03, fall back to f90 ---
find_library(
  LibXC_FORTRAN_LIBRARIES
  NAMES xcf03 xcf90
  HINTS ${_LibXC_PATHS}
  PATH_SUFFIXES "libxc/lib" "libxc/lib64" "libxc" "lib" "lib64")

# --- C header (always required, separate from Fortran modules) ---
find_path(
  LibXC_C_INCLUDE_DIR
  NAMES xc.h
  HINTS ${_LibXC_PATHS}
  PATH_SUFFIXES "inc" "libxc" "libxc/include" "include/libxc" "include")

# --- Fortran modules: f03 first, then legacy f90 ---
find_path(
  LibXC_F03_INCLUDE_DIR
  NAMES xc_f03_lib_m.mod xc_f03_types_m.mod
  HINTS ${_LibXC_PATHS}
  PATH_SUFFIXES
    "inc"
    "libxc"
    "libxc/include"
    "include/libxc"
    "include"
    "modules"
    "mod")

if(LibXC_F03_INCLUDE_DIR)
  set(LibXC_Fortran_INCLUDE_DIR "${LibXC_F03_INCLUDE_DIR}")
else()
  find_path(
    LibXC_F90_INCLUDE_DIR
    NAMES xc_f90_types_m.mod xc_f90_lib_m.mod
    HINTS ${_LibXC_PATHS}
    PATH_SUFFIXES
      "inc"
      "libxc"
      "libxc/include"
      "include/libxc"
      "include"
      "modules"
      "mod")
  set(LibXC_Fortran_INCLUDE_DIR "${LibXC_F90_INCLUDE_DIR}")
endif()

# Merge include dirs (C + Fortran, deduplicated)
set(LibXC_INCLUDE_DIRS ${LibXC_C_INCLUDE_DIR})
if(LibXC_Fortran_INCLUDE_DIR)
  list(APPEND LibXC_INCLUDE_DIRS ${LibXC_Fortran_INCLUDE_DIR})
  list(REMOVE_DUPLICATES LibXC_INCLUDE_DIRS)
endif()

# --- version from xc_version.h (when present) ---
set(LibXC_VERSION "")
if(LibXC_C_INCLUDE_DIR AND EXISTS "${LibXC_C_INCLUDE_DIR}/xc_version.h")
  file(STRINGS "${LibXC_C_INCLUDE_DIR}/xc_version.h" _libxc_version_defs
       REGEX "^#define +XC_(MAJOR|MINOR|MICRO)_VERSION")
  set(_libxc_v_major "")
  set(_libxc_v_minor "")
  set(_libxc_v_micro "")
  foreach(_line IN LISTS _libxc_version_defs)
    if(_line MATCHES "#define +XC_MAJOR_VERSION +([0-9]+)")
      set(_libxc_v_major "${CMAKE_MATCH_1}")
    elseif(_line MATCHES "#define +XC_MINOR_VERSION +([0-9]+)")
      set(_libxc_v_minor "${CMAKE_MATCH_1}")
    elseif(_line MATCHES "#define +XC_MICRO_VERSION +([0-9]+)")
      set(_libxc_v_micro "${CMAKE_MATCH_1}")
    endif()
  endforeach()
  # note: version components are compared as strings - a component of "0"
  # would be falsy in a plain if()
  if(NOT _libxc_v_major STREQUAL "")
    set(LibXC_VERSION "${_libxc_v_major}")
    if(NOT _libxc_v_minor STREQUAL "")
      string(APPEND LibXC_VERSION ".${_libxc_v_minor}")
      if(NOT _libxc_v_micro STREQUAL "")
        string(APPEND LibXC_VERSION ".${_libxc_v_micro}")
      endif()
    endif()
  endif()
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  LibXC
  REQUIRED_VARS LibXC_LIBRARIES LibXC_FORTRAN_LIBRARIES LibXC_C_INCLUDE_DIR
  VERSION_VAR LibXC_VERSION
  FAIL_MESSAGE
    "Could not find LibXC (need libxc + libxcf03/xcf90 and xc_f03_*.mod or xc_f90_*.mod). Set LibXC_ROOT."
)

if(LibXC_FOUND)
  if(NOT LibXC_Fortran_INCLUDE_DIR)
    message(WARNING "LibXC Fortran module dir not found. "
                    "Fortran interface may not compile correctly.")
  endif()
  vasp_report(LibXC
    "Found LibXC ${LibXC_VERSION}: ${LibXC_LIBRARIES} "
    "(Fortran: ${LibXC_FORTRAN_LIBRARIES}; include dirs: ${LibXC_INCLUDE_DIRS})")
  if(NOT TARGET LibXC::libxc)
    add_library(LibXC::libxc INTERFACE IMPORTED)
  endif()
  set_property(
    TARGET LibXC::libxc PROPERTY INTERFACE_LINK_LIBRARIES ${LibXC_LIBRARIES}
                                 ${LibXC_FORTRAN_LIBRARIES})
  set_property(TARGET LibXC::libxc PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                                            ${LibXC_INCLUDE_DIRS})
endif()

mark_as_advanced(LibXC_LIBRARIES LibXC_FORTRAN_LIBRARIES LibXC_C_INCLUDE_DIR
                 LibXC_F03_INCLUDE_DIR LibXC_F90_INCLUDE_DIR LibXC_INCLUDE_DIRS)
