#!/usr/bin/env bash
# verify_config.sh — configure-only regression gate for vasp-cmake.
#
# Safety contract: this script NEVER prints VASP source content. All greps run
# against our own cmake status messages and against *generated* build files,
# and only booleans / counts are echoed. The compile phase is never run.
#
# Scenarios (all configure + generate only, Unix Makefiles generator):
#   1 default     : SCALAPACK=OFF, nothing else
#   2 spack-sim   : every optional lib via explicit ROOTs, VASP_OPENMP=OFF,
#                   shmem trio on (mirrors spack package.py cmake_args)
#   3 dftd4-v3    : dftd4 3.7.0 + VASP_DFTD4_API=V3 (fallback search path)
#   4 dftd4-v4    : dftd4 4.2.0 + VASP_DFTD4_API=V4 (fallback search path)
#   5 dftd4-fake  : hand-built prefix without a CMake config -> manual fallback
#   6 elpa        : ScaLAPACK + ELPA via pkg-config, VASP_OPENMP=ON
#
# Baseline: first run writes $BASELINE_DIR/summary.txt (set FORCE_BASELINE=1
# to overwrite); later runs diff against it and report regressions.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VASP_TGZ="${VASP_TGZ:-/home/shaojiehe/vasp.6.6.0.tgz}"
SPACK_OPT="${SPACK_OPT:-/home/shaojiehe/spack/opt/spack}"
WORK="${WORK:-/tmp/vasp-verify}"
BASELINE_DIR="${BASELINE_DIR:-/tmp/vasp_verify_baseline}"

[[ -f "$VASP_TGZ" ]] || { echo "FATAL: VASP tarball not found: $VASP_TGZ (set VASP_TGZ)"; exit 2; }
[[ -d "$SPACK_OPT" ]] || { echo "FATAL: spack opt dir not found: $SPACK_OPT (set SPACK_OPT)"; exit 2; }
command -v pkg-config >/dev/null || { echo "FATAL: pkg-config not available"; exit 2; }

# ---------------------------------------------------------------------------
# locate spack prefixes (first match across arch dirs)
# ---------------------------------------------------------------------------
find_prefix() {
  local pat=$1 p
  for d in "$SPACK_OPT"/linux-*/; do
    p=$(ls -d "${d}"$pat 2>/dev/null | head -n1 || true)
    if [[ -n "${p:-}" ]]; then echo "$p"; return 0; fi
  done
  return 1
}

need() { local v=$1; shift; if ! eval "$v=\$(find_prefix \"\$1\")"; then echo "FATAL: spack prefix not found for $v ($1)"; exit 2; fi; }
need OMPI       'openmpi-5.0.10-*'
need SCALAPACK  'netlib-scalapack-2.2.3-*'
need HDF5       'hdf5-1.14.6-*'
need LIBXC      'libxc-7.*-*'
need LIBBEEF    'libbeef-*'
need DFTD4_V3   'dftd4-3.7.0-*'
need DFTD4_V4   'dftd4-4.2.0-*'
# 1.2.1 is the cmake-built install (ships lib/cmake/s-dftd3, like spack's
# "simple-dftd3 build_system=cmake"); the 1.4.0 install has no config package
need SDFTD3     'simple-dftd3-1.2*'
need MCTCLIB    'mctc-lib-0.4*'
need TOMLF      'toml-f-0.4*'
need JONQUIL    'jonquil-*'
need MULTICHARGE 'multicharge-0.5*'
need LIBMBD     'libmbd-*'
need WANNIER90  'wannier90-*'
need ELPA       'elpa-2026*'

# ---------------------------------------------------------------------------
# scratch tree
# ---------------------------------------------------------------------------
rm -rf "$WORK"
mkdir -p "$WORK"
tar xzf "$VASP_TGZ" -C "$WORK"
VTREE="$WORK/$(ls "$WORK")"
[[ -d "$VTREE/src" ]] || { echo "FATAL: unexpected tarball layout"; exit 2; }
rm -rf "$VTREE/cmake"
cp -r "$REPO_ROOT" "$VTREE/cmake"
rm -rf "$VTREE/cmake/.git" "$VTREE/cmake/.opencode" "$VTREE/cmake/.serena" \
       "$VTREE/cmake/tools" "$VTREE/cmake/docs" \
       "$VTREE/cmake/vasp_makefile_include_example"
(cd "$VTREE" && bash cmake/setup.sh) >/dev/null 2>&1

export PATH="$OMPI/bin:$PATH"
export LD_LIBRARY_PATH="$OMPI/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CC="$OMPI/bin/mpicc"; FC="$OMPI/bin/mpif90"

# fake dftd4 prefix: real lib + modules, no CMake config (scenario 5)
FAKE="$WORK/fake-dftd4"
mkdir -p "$FAKE/lib" "$FAKE/include/dftd4"
cp -P "$DFTD4_V4"/lib/libdftd4.so* "$FAKE/lib/" 2>/dev/null || cp "$DFTD4_V4"/lib/libdftd4.a "$FAKE/lib/"
cp "$DFTD4_V4"/include/dftd4/*/*.mod "$FAKE/include/dftd4/" 2>/dev/null || true

# ---------------------------------------------------------------------------
# scenario runner + assertions
# # assertions below intentionally run with errexit disabled: a failing check
# # must be recorded, not abort the run
# ---------------------------------------------------------------------------
set +e
RESULTS="$WORK/summary.txt"; : >"$RESULTS"
FAILED=0

run_cmake() { # <name> [cmake args...] -> exit code into $rc
  local name=$1; shift
  mkdir -p "$WORK/build-$name"
  if (cd "$WORK/build-$name" && cmake "$VTREE" "$@" >"$WORK/log-$name.txt" 2>&1); then rc=0; else rc=1; fi
}

check() { # <label> <ok:0|1>
  local label=$1 ok=$2
  if [[ $ok -eq 0 ]]; then echo "PASS  $label" | tee -a "$RESULTS"
  else echo "FAIL  $label" | tee -a "$RESULTS"; FAILED=1; fi
}

log_has() { grep -qF -- "$1" "$WORK/log-$2.txt"; }           # -> status 0/1
define_count() { grep -rhoE -- "$2" "$WORK/build-$1/src/CMakeFiles" 2>/dev/null | sort -u | wc -l; }

# spack puts the full transitive closure of dependency prefixes on
# CMAKE_PREFIX_PATH; mirror that (config-mode chains need it)
DEPCHAIN="$MCTCLIB;$TOMLF;$JONQUIL;$MULTICHARGE"

# --- scenario 1: default -----------------------------------------------------
run_cmake default -DVASP_TESTSUITE=OFF -DVASP_SCALAPACK=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC
check "s1 default: configure exit=0 (rc=$rc)" $rc

# --- scenario 2: spack full simulation --------------------------------------
run_cmake spack-sim -DVASP_TESTSUITE=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC -DVASP_OPENMP=OFF \
  -DCMAKE_PREFIX_PATH="$DFTD4_V3;$SDFTD3;$DEPCHAIN" \
  -DVASP_SCALAPACK=ON  -DSCALAPACK_ROOT="$SCALAPACK" \
  -DVASP_HDF5=ON       -DHDF5_ROOT="$HDF5" \
  -DVASP_LIBXC=ON      -DLibXC_ROOT="$LIBXC" \
  -DVASP_LIBBEEF=ON    -DLIBBEEF_ROOT="$LIBBEEF" \
  -DVASP_DFTD4=ON      -DDFTD4_ROOT="$DFTD4_V3" -DVASP_DFTD4_API=V3 \
  -DVASP_SDFTD3=ON \
  -DVASP_LIBMBD=ON     -DLIBMBD_ROOT="$LIBMBD" \
  -DVASP_WANNIER90=ON  -DWANNIER90_ROOT="$WANNIER90" \
  -DVASP_FFTLIB=OFF -DVASP_VASPSOL=ON -DVASP_VTST=OFF \
  -DVASP_SHMEM=ON -DVASP_SHMEM_BCAST=ON -DVASP_SHMEM_RPROJ=ON
check "s2 spack-sim: configure exit=0 (rc=$rc)" $rc
for kw in "Found Wannier90 library" "Found libbeef" "Found DFTD4 library" \
          "Found SDFTD3" "Found LIBMBD" "Found LibXC" "Found HDF5" \
          "Found SCALAPACK" "Found FFTW"; do
  log_has "$kw" spack-sim; check "s2 spack-sim: status line present [$kw]" $?
done
n=$(define_count spack-sim '\-DDFTD4_API_V3\b'); [[ $n -ge 1 ]]; check "s2 spack-sim: define DFTD4_API_V3 present (targets=$n)" $?
n=$(define_count spack-sim '\-DDFTD4\b'); [[ $n -eq 0 ]]; check "s2 spack-sim: define DFTD4 absent (targets=$n)" $?

# --- scenario 3: dftd4 3.7.0 + API=V3 (config mode, like spack) -------------
run_cmake dftd4-v3 -DVASP_TESTSUITE=OFF -DVASP_SCALAPACK=OFF -DVASP_HDF5=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_PREFIX_PATH="$DFTD4_V3;$DEPCHAIN" \
  -DVASP_DFTD4=ON -DDFTD4_ROOT="$DFTD4_V3" -DVASP_DFTD4_API=V3
check "s3 dftd4-v3: configure exit=0 (rc=$rc)" $rc
log_has "Found DFTD4 library" dftd4-v3; check "s3 dftd4-v3: found line present" $?
n=$(define_count dftd4-v3 '\-DDFTD4_API_V3\b'); [[ $n -ge 1 ]]; check "s3 dftd4-v3: define DFTD4_API_V3 present (targets=$n)" $?
n=$(define_count dftd4-v3 '\-DDFTD4\b'); [[ $n -eq 0 ]]; check "s3 dftd4-v3: define DFTD4 absent (targets=$n)" $?

# --- scenario 4: dftd4 4.2.0 + API=V4 (config mode, like spack) -------------
run_cmake dftd4-v4 -DVASP_TESTSUITE=OFF -DVASP_SCALAPACK=OFF -DVASP_HDF5=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_PREFIX_PATH="$DFTD4_V4;$DEPCHAIN" \
  -DVASP_DFTD4=ON -DDFTD4_ROOT="$DFTD4_V4" -DVASP_DFTD4_API=V4
check "s4 dftd4-v4: configure exit=0 (rc=$rc)" $rc
n=$(define_count dftd4-v4 '\-DDFTD4\b'); [[ $n -ge 1 ]]; check "s4 dftd4-v4: define DFTD4 present (targets=$n)" $?
n=$(define_count dftd4-v4 '\-DDFTD4_API_V3\b'); [[ $n -eq 0 ]]; check "s4 dftd4-v4: define DFTD4_API_V3 absent (targets=$n)" $?

# --- scenario 5: fake prefix, manual fallback --------------------------------
run_cmake dftd4-fake -DVASP_TESTSUITE=OFF -DVASP_SCALAPACK=OFF -DVASP_HDF5=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC \
  -DVASP_DFTD4=ON -DDFTD4_ROOT="$FAKE" -DVASP_DFTD4_API=V4
check "s5 dftd4-fake: configure exit=0 (rc=$rc)" $rc
n=$(define_count dftd4-fake '\-DDFTD4\b'); [[ $n -ge 1 ]]; check "s5 dftd4-fake: define DFTD4 present (targets=$n)" $?

# --- scenario 6: ELPA via pkg-config -----------------------------------------
run_cmake elpa -DVASP_TESTSUITE=OFF \
  -DCMAKE_Fortran_COMPILER=$FC -DCMAKE_C_COMPILER=$CC -DVASP_OPENMP=ON \
  -DVASP_SCALAPACK=ON -DSCALAPACK_ROOT="$SCALAPACK" \
  -DVASP_ELPA=ON -DELPA_ROOT="$ELPA"
check "s6 elpa: configure exit=0 (rc=$rc)" $rc
log_has "Found ELPA (pkg-config)" elpa; check "s6 elpa: pkg-config path used" $?

# ---------------------------------------------------------------------------
# baseline compare
# ---------------------------------------------------------------------------
if [[ ! -f "$BASELINE_DIR/summary.txt" || "${FORCE_BASELINE:-0}" = 1 ]]; then
  mkdir -p "$BASELINE_DIR"
  cp "$RESULTS" "$BASELINE_DIR/summary.txt"
  echo "--- baseline written to $BASELINE_DIR/summary.txt ---"
elif diff -u "$BASELINE_DIR/summary.txt" "$RESULTS" >"$WORK/baseline.diff" 2>&1; then
  echo "--- baseline comparison: no drift ---"
else
  echo "--- REGRESSION vs baseline (PASS->FAIL lines below) ---"
  grep '^[-+]FAIL\|^[-+]PASS' "$WORK/baseline.diff" || true
  # any FAIL in current run is a hard failure regardless of baseline
fi

echo "==============================="
if [[ $FAILED -eq 0 ]]; then echo "RESULT: ALL SCENARIOS PASS"; else echo "RESULT: FAILURES PRESENT"; fi
echo "==============================="
exit $FAILED
