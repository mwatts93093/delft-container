#!/bin/bash
source /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1

export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/proj/lib:$LD_LIBRARY_PATH

INSTALL_BIN="/build/Delft3D/build_dflowfm/install/bin"
export PATH="$INSTALL_BIN:$PATH"

# If arguments were passed, execute them directly
if [ $# -gt 0 ]; then
    exec "$@"
fi

# Default: interactive shell
exec /bin/bash
