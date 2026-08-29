# vasp_find_utils.cmake
# ---------------------
# Shared helpers for the custom Find<Package>.cmake modules of this repo.
# Written from scratch for vasp-cmake; not derived from any other project.

include_guard(GLOBAL)

#[=======================================================================[.rst:
vasp_pkg_root
-------------

::

  vasp_pkg_root(<out-var> <NAME> <PkgName> [EXTRA_VARS <var>...])

Collect candidate installation prefixes for an external package, best
guess first, into the list variable ``<out-var>``:

1. the cache variables ``<NAME>_ROOT`` and ``<PkgName>_ROOT`` (plus any
   ``EXTRA_VARS``, e.g. case variants such as ``Libxc_ROOT`` or a plain
   ``..._DIR`` hint) and their environment equivalents
2. environment only: ``<NAME>HOME`` / ``<NAME>_HOME`` (classic HPC style)
3. environment only: ``EBROOT<NAME>`` (EasyBuild standard) and the
   ``EB<NAME>ROOT`` spelling some sites use
4. environment only: ``CRAY_<NAME>_PREFIX_DIR`` / ``CRAY_<NAME>_ROOT``
   (Cray Programming Environment modules)

Empty entries are dropped and duplicates removed. There is deliberately
no fallback default such as ``/usr``: CMake's own search procedure covers
the standard system prefixes, so injecting them here would only mask a
missing ROOT with a wrong system copy.

Typical use inside a find module::

  include(vasp_find_utils)
  vasp_pkg_root(_paths ELPA Elpa)
  find_library(... HINTS ${_paths} ...)
#]=======================================================================]

function(vasp_pkg_root _out _name _pkg)
  set(_prefixes)
  set(_root_vars "${_name}_ROOT" "${_pkg}_ROOT")
  if(ARGN)
    list(APPEND _root_vars ${ARGN})
  endif()

  foreach(_v IN LISTS _root_vars)
    if(DEFINED "${_v}" AND NOT "${${_v}}" STREQUAL "")
      list(APPEND _prefixes "${${_v}}")
    endif()
    if(DEFINED "ENV{${_v}}" AND NOT "$ENV{${_v}}" STREQUAL "")
      list(APPEND _prefixes "$ENV{${_v}}")
    endif()
  endforeach()

  # site-convention environment variables (no cache counterparts)
  foreach(_v "EBROOT${_name}" "EB${_name}ROOT"
              "CRAY_${_name}_PREFIX_DIR" "CRAY_${_name}_ROOT"
              "${_name}HOME" "${_name}_HOME")
    if(DEFINED "ENV{${_v}}" AND NOT "$ENV{${_v}}" STREQUAL "")
      list(APPEND _prefixes "$ENV{${_v}}")
    endif()
  endforeach()

  if(_prefixes)
    list(REMOVE_DUPLICATES _prefixes)
  endif()
  set("${_out}" "${_prefixes}" PARENT_SCOPE)
endfunction()

#[=======================================================================[.rst:
vasp_report
-----------

::

  vasp_report(<PKG> <message>...)

Print ``<message>`` as a STATUS line at most once per package ``<PKG>``.
``find_package`` may run a module several times during one configure
(e.g. REQUIRED retries), so a guard keeps the log readable without each
module having to maintain its own ``*_MESSAGE_SHOWN`` flag.
#]=======================================================================]

function(vasp_report _pkg)
  if(NOT VASP_REPORTED_${_pkg})
    message(STATUS "${ARGN}")
    set("VASP_REPORTED_${_pkg}" TRUE CACHE INTERNAL "vasp_report guard")
  endif()
endfunction()
