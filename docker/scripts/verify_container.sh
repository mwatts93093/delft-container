#!/usr/bin/env bash
#
# Functional acceptance test for the Delft3D-FM container.
#
# The default test runs a shortened copy of the bundled f34 model in /tmp and
# validates that the resulting NetCDF file is usable as UGRID data. Nothing in
# the bind-mounted example directory is modified.
#
# Options:
#   --quick  Validate the existing bundled f34 output without running the solver.
#   --gui    Also verify that the container can reach the WSLg X display.

set -Eeuo pipefail

mode="smoke"
check_gui=false

while (($#)); do
    case "$1" in
        --quick) mode="quick" ;;
        --gui) check_gui=true ;;
        *)
            echo "Usage: $0 [--quick] [--gui]" >&2
            exit 2
            ;;
    esac
    shift
done

pass_count=0
work_dir=""

pass() {
    printf 'PASS  %s\n' "$1"
    pass_count=$((pass_count + 1))
}

fail() {
    printf 'FAIL  %s\n' "$1" >&2
    exit 1
}

cleanup() {
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        rm -rf -- "$work_dir"
    fi
}
trap cleanup EXIT

# Intel-built NetCDF libraries require the oneAPI runtime libraries.
# Intel's environment script probes unset variables and is not nounset-safe.
# shellcheck disable=SC1091
set +u
source /opt/intel/oneapi/setvars.sh --force >/dev/null 2>&1
set -u
export LD_LIBRARY_PATH="/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/gklib/lib:/opt/proj/lib:/opt/proj/lib64:${LD_LIBRARY_PATH:-}"

required_commands=(dflowfm dimr mpirun ncview python3 nc-config nf-config)
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 ||
        fail "required command is missing: $command_name"
done
pass "solver, coupling, MPI, NetCDF, Python, and ncview commands are installed"

python3 - <<'PY' >/dev/null
import netCDF4
import numpy
import pandas
import scipy
import xarray
PY
pass "scientific Python stack imports with the Intel runtime"

version_output="$(dflowfm --version 2>&1)"
grep -q "D-Flow FM Version" <<<"$version_output" ||
    fail "dflowfm did not report its version"
for feature in MPI PETSc METIS PROJ GDAL; do
    grep -Eq "${feature}[[:space:]]*: yes" <<<"$version_output" ||
        fail "dflowfm was built without expected feature: $feature"
done
pass "dflowfm starts and reports the expected compiled features"

example_dir="/workspace/examples/dflowfm/01_dflowfm_sequential/dflowfm"
[[ -f "$example_dir/f34.mdu" ]] ||
    fail "bundled f34 model was not found at $example_dir"

if [[ "$mode" == "smoke" ]]; then
    work_dir="$(mktemp -d /tmp/delft3d-verify.XXXXXX)"
    cp -a "$example_dir/." "$work_dir/"
    rm -rf -- "$work_dir/output"
    mkdir -p "$work_dir/output"

    # Reduce the 25-hour example to ten simulated minutes and emit multiple
    # map/history records. This exercises parsing, numerics, and NetCDF output.
    sed -i \
        -e 's/^\([[:space:]]*StopDateTime[[:space:]]*=\).*/\1 19900805001000/' \
        -e 's/^\([[:space:]]*MapInterval[[:space:]]*=\).*/\1 300/' \
        "$work_dir/f34.mdu"

    if ! (cd "$work_dir" && timeout 300 dflowfm f34.mdu >solver.log 2>&1); then
        echo "----- solver log (last 80 lines) -----" >&2
        tail -n 80 "$work_dir/solver.log" >&2 || true
        fail "shortened f34 simulation did not complete"
    fi
    map_file="$work_dir/output/f34_map.nc"
    pass "shortened f34 simulation completed in an isolated temporary directory"
else
    map_file="$example_dir/output/f34_map.nc"
fi

[[ -s "$map_file" ]] || fail "map output is missing or empty: $map_file"

MAP_FILE="$map_file" python3 - <<'PY'
import os

import netCDF4
import numpy as np

path = os.environ["MAP_FILE"]
with netCDF4.Dataset(path) as dataset:
    conventions = str(getattr(dataset, "Conventions", ""))
    if "UGRID" not in conventions:
        raise SystemExit(f"{path}: Conventions does not identify UGRID: {conventions!r}")

    topology = [
        name
        for name, variable in dataset.variables.items()
        if getattr(variable, "cf_role", "") == "mesh_topology"
    ]
    if not topology:
        raise SystemExit(f"{path}: no variable has cf_role='mesh_topology'")

    if "time" not in dataset.dimensions or len(dataset.dimensions["time"]) < 1:
        raise SystemExit(f"{path}: no populated time dimension")

    water_level_names = [
        name for name in dataset.variables
        if name == "s1" or name.endswith("_s1")
    ]
    if not water_level_names:
        raise SystemExit(f"{path}: no water-level variable (s1) found")

    values = np.ma.asarray(dataset.variables[water_level_names[0]][:])
    if values.count() == 0 or not np.isfinite(values.compressed()).all():
        raise SystemExit(f"{path}: water-level data is empty or non-finite")

    print(
        f"UGRID={conventions}; topology={topology[0]}; "
        f"time_records={len(dataset.dimensions['time'])}; "
        f"water_level={water_level_names[0]}"
    )
PY
pass "NetCDF output contains finite water-level data on a UGRID mesh"

if [[ "$check_gui" == true ]]; then
    [[ -n "${DISPLAY:-}" ]] || fail "DISPLAY is empty; invoke the test from WSL2/WSLg"
    [[ -d /tmp/.X11-unix ]] || fail "/tmp/.X11-unix is not mounted"
    timeout 10 xdpyinfo >/dev/null 2>&1 ||
        fail "the container cannot connect to the WSLg X display ($DISPLAY)"
    pass "ncview can use the reachable WSLg X display ($DISPLAY)"
fi

printf '\nFunctional verification passed (%d checks, mode=%s, gui=%s).\n' \
    "$pass_count" "$mode" "$check_gui"
