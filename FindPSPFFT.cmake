# .rst: FindPSPFFT
# ----------
#
# Find the PSPFFT parallel sparse FFT library (for SCPC in VASP).
#
# Imported target::
#
# PSPFFT::pspfft

include(vasp_find_utils)

vasp_pkg_root(_PSPFFT_PATHS PSPFFT PSPFFT)

find_library(
  PSPFFT_LIBRARIES
  NAMES pspfft
  HINTS ${_PSPFFT_PATHS}
  PATH_SUFFIXES "lib" "lib64")

find_path(
  PSPFFT_INCLUDE_DIRS
  NAMES pspfft.h psp_fft.mod
  HINTS ${_PSPFFT_PATHS}
  PATH_SUFFIXES "include" "inc" "modules")

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  PSPFFT
  REQUIRED_VARS PSPFFT_INCLUDE_DIRS PSPFFT_LIBRARIES
  FAIL_MESSAGE "Set PSPFFT_ROOT to the PSPFFT installation")

if(PSPFFT_FOUND)
  if(NOT PSPFFT_MESSAGE_SHOWN)
    vasp_report(PSPFFT "Found PSPFFT: ${PSPFFT_LIBRARIES}")
  endif()
  set(PSPFFT_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET PSPFFT::pspfft)
    add_library(PSPFFT::pspfft UNKNOWN IMPORTED)
    set_target_properties(
      PSPFFT::pspfft
      PROPERTIES IMPORTED_LOCATION "${PSPFFT_LIBRARIES}"
                 INTERFACE_INCLUDE_DIRECTORIES "${PSPFFT_INCLUDE_DIRS}")
  endif()
endif()

mark_as_advanced(PSPFFT_FOUND PSPFFT_LIBRARIES PSPFFT_INCLUDE_DIRS)
