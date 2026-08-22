#.rst:
# FindSDFTD3
# -----------
#
# This module tries to find the simple-DFTD3 library
# (https://github.com/dftd3/simple-dftd3), which provides the Fortran module
# "dftd3" used by the VASP DFT-D3 interface.
#
# The library ships its own CMake package config under the package name
# "s-dftd3", which is preferred because it knows the compiler specific Fortran
# module directory (include/s-dftd3/<CompilerId>-<Version>) and carries the
# mctc-lib dependency - relevant here because simple-DFTD3 is commonly
# installed as a static archive, which does not record its dependencies.
# If no config package is found we fall back to a plain library + module
# directory search based on SDFTD3_ROOT / SIMPLE_DFTD3_ROOT.
#
# The following variables are set
#
# ::
#
#   SDFTD3_FOUND          - True if simple-DFTD3 is found
#   SDFTD3_LIBRARIES      - The required libraries
#   SDFTD3_INCLUDE_DIRS   - The required include / Fortran module directories
#
# The following import target is created
#
# ::
#
#   SDFTD3::sdftd3

# set paths to look for library from ROOT variables. If new policy is set, find_library() automatically uses them.
set(_SDFTD3_PATHS ${SDFTD3_ROOT} $ENV{SDFTD3_ROOT}
                  ${SIMPLE_DFTD3_ROOT} $ENV{SIMPLE_DFTD3_ROOT}
                  ${S_DFTD3_ROOT} $ENV{S_DFTD3_ROOT})

set(SDFTD3_LIBRARIES)
set(SDFTD3_INCLUDE_DIRS)
set(_SDFTD3_LINK_TARGET)

# ---------------------------------------------------------------------------
# The simple-DFTD3 config package names OpenMP::OpenMP_Fortran in the link interface
# of its imported targets, but includes those targets before it runs
# find_dependency(OpenMP) itself. Without that target the generate step fails,
# and VASP only searches OpenMP when VASP_OPENMP is ON - so make sure it exists.
# If we are the ones creating it, the project is not built with OpenMP: keep the
# runtime the external library needs, but do not let the OpenMP compile flag
# propagate into the VASP sources.
# ---------------------------------------------------------------------------
if(NOT TARGET OpenMP::OpenMP_Fortran)
  find_package(OpenMP QUIET COMPONENTS Fortran)
  if(TARGET OpenMP::OpenMP_Fortran)
    set_property(TARGET OpenMP::OpenMP_Fortran PROPERTY INTERFACE_COMPILE_OPTIONS "")
  endif()
endif()

# ---------------------------------------------------------------------------
# 1) preferred: the CMake package config shipped with simple-DFTD3
#    CONFIG mode only, so this never recurses back into this find module
# ---------------------------------------------------------------------------
if(NOT TARGET s-dftd3::s-dftd3)
  find_package(s-dftd3 CONFIG QUIET)
endif()

if(TARGET s-dftd3::s-dftd3)
  set(_SDFTD3_LINK_TARGET s-dftd3::s-dftd3)
  if(s-dftd3_INCLUDE_DIRS)
    set(SDFTD3_INCLUDE_DIRS ${s-dftd3_INCLUDE_DIRS})
  else()
    # older configs only carry the dirs on the library target
    if(TARGET s-dftd3::s-dftd3-lib)
      get_target_property(_sd3_incs s-dftd3::s-dftd3-lib INTERFACE_INCLUDE_DIRECTORIES)
    else()
      get_target_property(_sd3_incs s-dftd3::s-dftd3 INTERFACE_INCLUDE_DIRECTORIES)
    endif()
    if(_sd3_incs)
      set(SDFTD3_INCLUDE_DIRS ${_sd3_incs})
    endif()
  endif()
  # the actual library file, for reporting
  if(TARGET s-dftd3::s-dftd3-lib)
    foreach(_p IMPORTED_LOCATION IMPORTED_LOCATION_RELEASE
               IMPORTED_LOCATION_RELWITHDEBINFO IMPORTED_LOCATION_NOCONFIG)
      get_target_property(_sd3_loc s-dftd3::s-dftd3-lib ${_p})
      if(_sd3_loc AND NOT SDFTD3_LIBRARIES)
        set(SDFTD3_LIBRARIES "${_sd3_loc}")
      endif()
    endforeach()
  endif()
  if(NOT SDFTD3_LIBRARIES)
    set(SDFTD3_LIBRARIES s-dftd3::s-dftd3)
  endif()
else()
  # -------------------------------------------------------------------------
  # 2) fallback: search library and Fortran module directory by hand
  # -------------------------------------------------------------------------
  find_library(
      SDFTD3_LIBRARY
      NAMES s-dftd3 sdftd3
      HINTS ${_SDFTD3_PATHS}
      PATH_SUFFIXES "lib" "lib64" "s-dftd3/lib" "s-dftd3/lib64"
  )

  # the Fortran modules usually live in a compiler specific subdirectory,
  # e.g. include/s-dftd3/IntelLLVM-2026.0.0 - collect candidates by globbing
  set(_SDFTD3_MODULE_HINTS)
  foreach(_prefix IN LISTS _SDFTD3_PATHS)
    file(GLOB _sd3_mod_files
      "${_prefix}/include/dftd3.mod"
      "${_prefix}/include/*/dftd3.mod"
      "${_prefix}/include/s-dftd3/*/dftd3.mod"
      "${_prefix}/lib/*/dftd3.mod"
      "${_prefix}/lib64/*/dftd3.mod"
      "${_prefix}/modules/dftd3.mod"
    )
    foreach(_sd3_mod_file IN LISTS _sd3_mod_files)
      get_filename_component(_sd3_mod_dir "${_sd3_mod_file}" DIRECTORY)
      list(APPEND _SDFTD3_MODULE_HINTS "${_sd3_mod_dir}")
    endforeach()
  endforeach()

  find_path(
      SDFTD3_MODULE_DIR
      NAMES dftd3.mod
      HINTS ${_SDFTD3_MODULE_HINTS} ${_SDFTD3_PATHS}
      PATH_SUFFIXES "include" "include/s-dftd3" "modules" "inc"
  )

  # the interface uses error_type / structure_type from mctc-lib, so VASP needs
  # its modules and - for a static simple-DFTD3 - its library as well
  set(_MCTC_MODULE_HINTS)
  foreach(_prefix IN ITEMS ${_SDFTD3_PATHS} $ENV{MCTC_LIB_ROOT} ${MCTC_LIB_ROOT})
    file(GLOB _mctc_mod_files
      "${_prefix}/include/mctc_env.mod"
      "${_prefix}/include/*/mctc_env.mod"
      "${_prefix}/include/mctc-lib/*/mctc_env.mod"
    )
    foreach(_mctc_mod_file IN LISTS _mctc_mod_files)
      get_filename_component(_mctc_mod_dir "${_mctc_mod_file}" DIRECTORY)
      list(APPEND _MCTC_MODULE_HINTS "${_mctc_mod_dir}")
    endforeach()
  endforeach()
  find_path(
      MCTC_LIB_MODULE_DIR
      NAMES mctc_env.mod
      HINTS ${_MCTC_MODULE_HINTS}
      PATH_SUFFIXES "include" "modules"
  )
  find_library(MCTC_LIB_LIBRARY
      NAMES mctc-lib
      HINTS ${_SDFTD3_PATHS} $ENV{MCTC_LIB_ROOT} ${MCTC_LIB_ROOT}
      PATH_SUFFIXES "lib" "lib64")

  set(SDFTD3_LIBRARIES ${SDFTD3_LIBRARY})
  if(MCTC_LIB_LIBRARY)
    list(APPEND SDFTD3_LIBRARIES ${MCTC_LIB_LIBRARY})
  endif()

  set(SDFTD3_INCLUDE_DIRS ${SDFTD3_MODULE_DIR})
  if(MCTC_LIB_MODULE_DIR)
    list(APPEND SDFTD3_INCLUDE_DIRS ${MCTC_LIB_MODULE_DIR})
  endif()

  mark_as_advanced(SDFTD3_LIBRARY SDFTD3_MODULE_DIR MCTC_LIB_MODULE_DIR MCTC_LIB_LIBRARY)
endif()

# check if found
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(SDFTD3
                                  REQUIRED_VARS SDFTD3_INCLUDE_DIRS SDFTD3_LIBRARIES
                                  FAIL_MESSAGE "Could not find simple-DFTD3 library, please specify SDFTD3_ROOT or set as environment variable")

# add target to link against
if(SDFTD3_FOUND)
  if(NOT SDFTD3_MESSAGE_SHOWN)
    message(STATUS "Found simple-DFTD3 library: ${SDFTD3_LIBRARIES}")
    message(STATUS "simple-DFTD3 module directories: ${SDFTD3_INCLUDE_DIRS}")
  endif()
  set(SDFTD3_MESSAGE_SHOWN TRUE CACHE INTERNAL "Message shown flag")
  if(NOT TARGET SDFTD3::sdftd3)
      add_library(SDFTD3::sdftd3 INTERFACE IMPORTED)
  endif()
  if(_SDFTD3_LINK_TARGET)
    # link through the config target, it carries the transitive dependencies
    set_property(TARGET SDFTD3::sdftd3 PROPERTY INTERFACE_LINK_LIBRARIES ${_SDFTD3_LINK_TARGET})
  else()
    set_property(TARGET SDFTD3::sdftd3 PROPERTY INTERFACE_LINK_LIBRARIES ${SDFTD3_LIBRARIES})
  endif()
  set_property(TARGET SDFTD3::sdftd3 PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${SDFTD3_INCLUDE_DIRS})
endif()

# prevent clutter in cache
MARK_AS_ADVANCED(SDFTD3_FOUND SDFTD3_LIBRARIES SDFTD3_INCLUDE_DIRS)
