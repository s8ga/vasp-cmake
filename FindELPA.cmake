# .rst: FindELPA
# --------
#
# Find the ELPA eigenvalue solver library.
#
# Strategy: 1. pkg-config (preferred; handles version-specific dirs
# automatically) 2. Manual fallback: find_path (with glob for version-specific
# layout) + find_library
#
# When VASP_OPENMP is ON, prefers elpa_openmp over elpa (with a warning when
# only the serial flavor is found). If ELPA_FIND_VERSION is set (i.e.
# find_package(ELPA <version>)), the pkg-config search enforces it via a
# module spec, and a try_compile probe verifies that the Fortran modules are
# readable by the current compiler.
#
# Cache options:
#
#   ELPA_SKIP_PROBE - skip the try_compile probe (cross-compiling, etc.)
#
# Imported target::
#
#   ELPA::ELPA

include(FindPackageHandleStandardArgs)
include(vasp_find_utils)

vasp_pkg_root(_ELPA_PATHS ELPA Elpa)

set(ELPA_SKIP_PROBE OFF CACHE BOOL "Skip the ELPA try_compile probe (cross-compiling, etc.)")

# ---------------------------------------------------------------------------
# Probe: 'use elpa' forces the compiler to read elpa.mod, which catches an
# ELPA built with a different Fortran compiler (unreadable .mod files) at
# configure time instead of deep inside the VASP build. Success is cached;
# failure re-runs so a fixed installation recovers without cache surgery.
# ---------------------------------------------------------------------------
function(_elpa_run_probe)
  if(ELPA_SKIP_PROBE)
    return()
  endif()
  if(ELPA_PROBE_OK)
    return()
  endif()
  # try_compile's LINK_LIBRARIES does not propagate INTERFACE_INCLUDE_DIRECTORIES
  # to the probe source, so the include dirs are written into the probe project
  set(_probe_incs "${_elpa_inc_dirs}")
  if(NOT _probe_incs)
    set(_probe_incs "${ELPA_INCLUDE_DIR}")
  endif()
  list(REMOVE_DUPLICATES _probe_incs)
  string(REPLACE ";" "\" \"" _probe_incs_q "${_probe_incs}")
  set(_probe_src "${CMAKE_BINARY_DIR}/CMakeFiles/elpa_probe_src")
  file(WRITE "${_probe_src}/CMakeLists.txt"
"cmake_minimum_required(VERSION 3.20)
project(elpa_probe Fortran)
add_executable(elpa_probe elpa_probe.f90)
target_include_directories(elpa_probe PRIVATE \"${_probe_incs_q}\")
")
  file(WRITE "${_probe_src}/elpa_probe.f90"
"program elpa_probe
  use elpa
  implicit none
end program
")
  try_compile(_elpa_probe_result
    "${CMAKE_BINARY_DIR}/CMakeFiles/elpa_probe_build"
    "${_probe_src}"
    elpa_probe
    CMAKE_FLAGS "-DCMAKE_Fortran_COMPILER=${CMAKE_Fortran_COMPILER}"
    LINK_LIBRARIES ELPA::ELPA
    OUTPUT_VARIABLE _elpa_probe_out
  )
  if(_elpa_probe_result)
    set(ELPA_PROBE_OK TRUE CACHE INTERNAL "ELPA probe result")
  else()
    message(FATAL_ERROR
      "ELPA was found, but a test program containing 'use elpa' failed to\n"
      "compile. Most likely causes:\n"
      "  * ELPA was built with a different Fortran compiler than\n"
      "    ${CMAKE_Fortran_COMPILER} - Fortran .mod files are compiler-specific\n"
      "  * ELPA older than the 2021 API\n"
      "Set ELPA_SKIP_PROBE=ON to skip this check (e.g. when cross-compiling).")
  endif()
endfunction()

# --- 1) pkg-config (preferred) ---
set(_elpa_ver "")
if(ELPA_FIND_VERSION)
  set(_elpa_ver ">=${ELPA_FIND_VERSION}")
endif()

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
    pkg_search_module(ELPA QUIET IMPORTED_TARGET GLOBAL "elpa_openmp${_elpa_ver}")
  endif()
  if(NOT ELPA_FOUND)
    pkg_search_module(ELPA QUIET IMPORTED_TARGET GLOBAL "elpa${_elpa_ver}")
    if(ELPA_FOUND AND VASP_OPENMP AND ELPA_MODULE STREQUAL "elpa")
      message(WARNING
        "VASP_OPENMP is ON but only the serial 'elpa' flavor was found.\n"
        "Consider rebuilding ELPA with OpenMP (or +openmp in spack) for\n"
        "threaded ELPA solvers.")
    endif()
  endif()
  # a versioned search that failed deserves a better message than
  # "not found": check whether an outdated ELPA is visible instead
  if(NOT ELPA_FOUND AND ELPA_FIND_VERSION)
    pkg_search_module(_ELPA_OUTDATED QUIET elpa_openmp elpa)
    if(_ELPA_OUTDATED_FOUND
       AND _ELPA_OUTDATED_VERSION VERSION_LESS "${ELPA_FIND_VERSION}")
      message(FATAL_ERROR
        "ELPA ${_ELPA_OUTDATED_VERSION} is visible to pkg-config, but VASP "
        "needs at least ${ELPA_FIND_VERSION} (2021 API). Install a newer "
        "ELPA or point ELPA_ROOT at one.")
    endif()
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
  vasp_report(ELPA "Found ELPA (pkg-config): ${ELPA_VERSION} "
                   "(${ELPA_MODULE}) ${ELPA_LINK_LIBRARIES}")
  _elpa_run_probe()
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

if(ELPA_FIND_VERSION)
  message(WARNING
    "ELPA found via manual fallback: the requested version "
    "(${ELPA_FIND_VERSION}) cannot be verified without pkg-config. "
    "Make sure the installation provides the 2021 API.")
endif()

find_package_handle_standard_args(
  ELPA
  REQUIRED_VARS ELPA_INCLUDE_DIR ELPA_LIBRARIES
  FAIL_MESSAGE "Set ELPA_ROOT to an ELPA installation providing the 2021 API")

if(ELPA_FOUND)
  vasp_report(ELPA "Found ELPA (fallback): ${ELPA_LIBRARIES}")
  if(NOT TARGET ELPA::ELPA)
    add_library(ELPA::ELPA UNKNOWN IMPORTED)
    set_target_properties(
      ELPA::ELPA
      PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C"
                 IMPORTED_LOCATION "${ELPA_LIBRARIES}"
                 INTERFACE_INCLUDE_DIRECTORIES "${ELPA_INCLUDE_DIR}")
  endif()
  # BLACS/ScaLAPACK symbols: the pkg-config flavor carries them via
  # ELPA_LINK_LIBRARIES; add them here too when ScaLAPACK was already found
  if(TARGET SCALAPACK::SCALAPACK)
    set_property(TARGET ELPA::ELPA APPEND PROPERTY
                 INTERFACE_LINK_LIBRARIES SCALAPACK::SCALAPACK)
  endif()
  _elpa_run_probe()
endif()

mark_as_advanced(ELPA_LIBRARIES ELPA_INCLUDE_DIR)
