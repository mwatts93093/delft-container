#!/bin/bash
source /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1

echo "================================================"
echo "Delft3D-FM Container Information"
echo "================================================"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    echo "OS:           ${PRETTY_NAME}"
else
    echo "OS:           unknown"
fi
echo -n "Compiler:     "; ifort --version | head -n1
echo -n "NetCDF-C:     "; nc-config --version
echo -n "NetCDF-F:     "; nf-config --version
echo "HDF5:         1.12.2"
echo "PETSc:        3.19.4"
echo "METIS:        5.2.1"
echo "PROJ:         9.4.0"
echo "Delft3D:      DIMRset_2.30.17"
echo "================================================"
