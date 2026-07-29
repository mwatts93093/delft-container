#!/bin/bash
source /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1

export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/proj/lib:$LD_LIBRARY_PATH

INSTALL_BIN="/build/Delft3D/build_dflowfm/install/bin"

if [ -f "$INSTALL_BIN/run_dflowfm.sh" ]; then
    exec "$INSTALL_BIN/run_dflowfm.sh" "$@"
else
    echo "ERROR: Delft3D not compiled yet. Run: /build/build_delft3d.sh"
    exit 1
fi
