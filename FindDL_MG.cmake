# .rst: FindDL_MG
# ---------
#
# Find the DL_MG multigrid Poisson solver (for SCPC in VASP).
#
# Imported target::
#
# DL_MG::dlmg

include(vasp_find_utils)

vasp_pkg_root(_DL_MG_PATHS DL_MG DLMG)

find_library(
  DL_MG_LIBRARIES
  NAMES dlmg dl_mg
  HINTS ${_DL_MG_PATHS}
  PATH_SUFFIXES "lib" "lib64")

find_path(
  DL_MG_INCLUDE_DIRS
  NAMES dl_mg.h dl_mg_types.mod
  HINTS ${_DL_MG_PATHS}
  PATH_SUFFIXES "include" "inc" "modules")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  DL_MG
  REQUIRED_VARS DL_MG_INCLUDE_DIRS DL_MG_LIBRARIES
  FAIL_MESSAGE "Set DL_MG_ROOT to the DL_MG installation")

if(DL_MG_FOUND)
  if(NOT DL_MG_MESSAGE_SHOWN)
    vasp_report(DL_MG "Found DL_MG: ${DL_MG_LIBRARIES}")
  endif()
  set(DL_MG_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET DL_MG::dlmg)
    add_library(DL_MG::dlmg UNKNOWN IMPORTED)
    set_target_properties(
      DL_MG::dlmg
      PROPERTIES IMPORTED_LOCATION "${DL_MG_LIBRARIES}"
                 INTERFACE_INCLUDE_DIRECTORIES "${DL_MG_INCLUDE_DIRS}")
  endif()
endif()

mark_as_advanced(DL_MG_FOUND DL_MG_LIBRARIES DL_MG_INCLUDE_DIRS)
