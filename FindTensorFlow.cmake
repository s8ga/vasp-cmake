# .rst: FindTensorFlow
# --------------
#
# Find TensorFlow C++ libraries for VASPml GRACE support. Locates
# libtensorflow_cc and libtensorflow_framework.
#
# Supports two install layouts: 1. pip install: .so files in package root,
# headers in include/ e.g. .../site-packages/tensorflow/libtensorflow_cc.so.2 2.
# Standard/spack: .so files in lib/, headers in include/
#
# Set TENSORFLOW_ROOT to the tensorflow/ package dir (pip) or prefix (standard).
#
# Imported targets::
#
# TensorFlow::tensorflow_cc TensorFlow::tensorflow_framework

# Collect ROOT hints (always, regardless of CMP0074/CMP0144)
set(_TF_PATHS)
foreach(_v TENSORFLOW_ROOT TensorFlow_ROOT)
  if(DEFINED ${_v})
    list(APPEND _TF_PATHS "${${_v}}")
  endif()
  if(DEFINED ENV{${_v}})
    list(APPEND _TF_PATHS "$ENV{${_v}}")
  endif()
endforeach()

# Also check spack view / CMAKE_PREFIX_PATH for Python site-packages layouts
set(_TF_PYTHON_HINTS)
foreach(_p IN LISTS _TF_PATHS CMAKE_PREFIX_PATH)
  file(GLOB _tf_pydirs "${_p}/lib/python*/site-packages/tensorflow"
       "${_p}/lib64/python*/site-packages/tensorflow")
  list(APPEND _TF_PYTHON_HINTS ${_tf_pydirs})
endforeach()
list(REMOVE_DUPLICATES _TF_PYTHON_HINTS)

# Combine all search paths: explicit ROOT first, then Python site-packages
set(_TF_ALL_PATHS ${_TF_PATHS} ${_TF_PYTHON_HINTS})

# --- locate include dir (common to both layouts) ---
find_path(
  TENSORFLOW_INCLUDE_DIRS
  NAMES tensorflow/c/c_api.h
  HINTS ${_TF_ALL_PATHS}
  PATH_SUFFIXES "include")

# --- locate libraries ---
# pip layout: .so in the package root; standard: .so in lib/
find_library(
  TENSORFLOW_CC_LIBRARY
  NAMES tensorflow_cc libtensorflow_cc.so.2 libtensorflow_cc
  HINTS ${_TF_ALL_PATHS}
  PATH_SUFFIXES "" "lib" "lib64")

find_library(
  TENSORFLOW_FRAMEWORK_LIBRARY
  NAMES tensorflow_framework libtensorflow_framework.so.2
  HINTS ${_TF_ALL_PATHS}
  PATH_SUFFIXES "" "lib" "lib64")

set(TENSORFLOW_LIBRARIES ${TENSORFLOW_CC_LIBRARY})
if(TENSORFLOW_FRAMEWORK_LIBRARY)
  list(APPEND TENSORFLOW_LIBRARIES ${TENSORFLOW_FRAMEWORK_LIBRARY})
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
  TensorFlow
  REQUIRED_VARS TENSORFLOW_CC_LIBRARY TENSORFLOW_INCLUDE_DIRS
  FAIL_MESSAGE "Set TENSORFLOW_ROOT to the TensorFlow installation")

if(TensorFlow_FOUND)
  if(NOT TENSORFLOW_MESSAGE_SHOWN)
    message(STATUS "Found TensorFlow: ${TENSORFLOW_LIBRARIES}")
    message(STATUS "  includes: ${TENSORFLOW_INCLUDE_DIRS}")
  endif()
  set(TENSORFLOW_MESSAGE_SHOWN
      TRUE
      CACHE INTERNAL "flag")
  if(NOT TARGET TensorFlow::tensorflow_cc)
    add_library(TensorFlow::tensorflow_cc UNKNOWN IMPORTED)
    set_target_properties(
      TensorFlow::tensorflow_cc
      PROPERTIES IMPORTED_LOCATION "${TENSORFLOW_CC_LIBRARY}"
                 INTERFACE_INCLUDE_DIRECTORIES "${TENSORFLOW_INCLUDE_DIRS}")
  endif()
  if(TENSORFLOW_FRAMEWORK_LIBRARY)
    if(NOT TARGET TensorFlow::tensorflow_framework)
      add_library(TensorFlow::tensorflow_framework UNKNOWN IMPORTED)
      set_target_properties(
        TensorFlow::tensorflow_framework
        PROPERTIES IMPORTED_LOCATION "${TENSORFLOW_FRAMEWORK_LIBRARY}"
                   INTERFACE_INCLUDE_DIRECTORIES "${TENSORFLOW_INCLUDE_DIRS}")
    endif()
  endif()
endif()

mark_as_advanced(TENSORFLOW_CC_LIBRARY TENSORFLOW_FRAMEWORK_LIBRARY
                 TENSORFLOW_INCLUDE_DIRS)
