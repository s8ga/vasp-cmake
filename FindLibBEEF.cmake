# .rst: FindLibBEEF
# -----------
#
# Find the libbeef library (BEEF van der Waals functionals). Note: libbeef is
# Fortran-only and may not install headers; the include dir is optional.
#
# Result variables::
#
# LibBEEF_FOUND        - True if libbeef is found LIBBEEF_LIBRARIES    - The
# libraries LIBBEEF_INCLUDE_DIRS - Include directories (may be empty)
#
# Imported target::
#
# LibBEEF::libbeef

set(_LIBBEEF_PATHS)
set(_LIBBEEF_PATHS)
foreach(_v LIBBEEF_ROOT LibBEEF_ROOT)
  if(DEFINED ${_v} AND NOT "${${_v}}" STREQUAL "")
    list(APPEND _LIBBEEF_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}} AND NOT "$ENV{${_v}}" STREQUAL "")
    list(APPEND _LIBBEEF_PATHS "$ENV{${_v}}")
  endif()
endforeach()

find_library(
  LIBBEEF_LIBRARIES
  NAMES beef
  HINTS ${_LIBBEEF_PATHS}
  PATH_SUFFIXES "libbeef/lib" "libbeef/lib64" "libbeef" "lib" "lib64")

find_path(
  LIBBEEF_INCLUDE_DIRS
  NAMES beef.h mod_beef.mod
  HINTS ${_LIBBEEF_PATHS}
  PATH_SUFFIXES "include" "inc" "libbeef" "libbeef/include" "modules")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  LibBEEF
  REQUIRED_VARS LIBBEEF_LIBRARIES
  FAIL_MESSAGE "Set LIBBEEF_ROOT to the libbeef installation prefix")

if(LibBEEF_FOUND)
  if(NOT LIBBEEF_MESSAGE_SHOWN)
    message(STATUS "Found libbeef: ${LIBBEEF_LIBRARIES}")
  endif()
  set(LIBBEEF_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET LibBEEF::libbeef)
    add_library(LibBEEF::libbeef INTERFACE IMPORTED)
  endif()
  set_property(TARGET LibBEEF::libbeef PROPERTY INTERFACE_LINK_LIBRARIES
                                                ${LIBBEEF_LIBRARIES})
  if(LIBBEEF_INCLUDE_DIRS)
    set_property(TARGET LibBEEF::libbeef PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                                                  ${LIBBEEF_INCLUDE_DIRS})
  endif()
endif()

mark_as_advanced(LIBBEEF_FOUND LIBBEEF_LIBRARIES LIBBEEF_INCLUDE_DIRS)
