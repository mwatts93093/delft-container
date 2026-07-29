#!/bin/bash
set -e
set -o pipefail

echo "================================================"
echo "Building Delft3D-FM Suite"
echo "================================================"

source /opt/intel/oneapi/setvars.sh --force

cd /build/Delft3D

export NETCDF_DIR=/opt/netcdf
export HDF5_DIR=/opt/hdf5
export PETSC_DIR=/opt/petsc
export METIS_DIR=/opt/metis
export PROJ_DIR=/opt/proj
export PKG_CONFIG_PATH=/opt/netcdf/lib/pkgconfig:/opt/hdf5/lib/pkgconfig:/opt/petsc/lib/pkgconfig:/opt/proj/lib64/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/gklib/lib:/opt/proj/lib64:$LD_LIBRARY_PATH

# Force use of classic Intel compilers (ifort/icc/icpc) instead of ifx/icx/icpx
# The ifx compiler doesn't support some Fortran features used in Delft3D
export FC=ifort
export CC=icc
export CXX=icpc

# Add MPI library linking flags
# PETSc modules require MPI but the build system doesn't always link it
export I_MPI_ROOT=/opt/intel/oneapi/mpi/2021.10.0
export MPI_Fortran_LIBRARIES="${I_MPI_ROOT}/lib/libmpifort.so;${I_MPI_ROOT}/lib/release/libmpi.so"

# Limit parallel jobs to prevent memory exhaustion
# ifort is very memory-hungry with optimization flags
# Using single thread to ensure build completes within Docker memory limits
export MAKEFLAGS="-j1"
export CMAKE_BUILD_PARALLEL_LEVEL=1

# ============================================================
# Patch CMakeLists.txt to add BUILD_TESTING option
# The Delft3D build system doesn't have this option, so we add it
# ============================================================
echo "Patching CMakeLists.txt to disable tests..."

CMAKELISTS="/build/Delft3D/src/cmake/CMakeLists.txt"

# Add BUILD_TESTING option near the top of the file (after cmake_minimum_required)
sed -i '/cmake_minimum_required/a option(BUILD_TESTING "Build unit tests" OFF)' "$CMAKELISTS"

# Wrap enable_testing() in a conditional
sed -i 's/enable_testing()/if(BUILD_TESTING)\n  enable_testing()\nendif()/' "$CMAKELISTS"

# Comment out the unit_test_configuration.cmake include
sed -i 's|include(configurations/miscellaneous/unit_test_configuration.cmake)|if(BUILD_TESTING)\n  include(configurations/miscellaneous/unit_test_configuration.cmake)\nendif()|' "$CMAKELISTS"

# Comment out all add_subdirectory(test) calls throughout the project
# These try to use f90twtest function which requires the test framework
echo "Disabling test subdirectories..."
find /build/Delft3D/src -name "CMakeLists.txt" -exec sed -i 's/^[[:space:]]*add_subdirectory[[:space:]]*(test)/# DISABLED: add_subdirectory(test)/' {} \;

# Also disable test_ directories (test_dflowfm_kernel etc.)
find /build/Delft3D/src -name "CMakeLists.txt" -exec sed -i 's/^[[:space:]]*add_subdirectory[[:space:]]*(test_[^)]*)/# DISABLED: &/' {} \;

echo "CMakeLists.txt files patched successfully"

# ============================================================
# Add MPI to global CMake configuration
# PETSc requires MPI but the linker doesn't include it for all targets
# ============================================================
echo "Adding MPI to global CMake configuration..."
# Insert after the cmake_minimum_required line
sed -i '/cmake_minimum_required/a \
# Find and include MPI globally for PETSc support\
find_package(MPI REQUIRED)\
link_libraries(MPI::MPI_Fortran)' "$CMAKELISTS"
echo "Global MPI linking added"

# ============================================================
# Remove UTF-8 BOM from Fortran files
# Some files have BOM that ifort can't handle
# ============================================================
echo "Removing UTF-8 BOMs from Fortran files..."
find /build/Delft3D/src -type f \( -name "*.f90" -o -name "*.F90" -o -name "*.f" -o -name "*.F" \) -exec sed -i '1s/^\xef\xbb\xbf//' {} \;
echo "BOMs removed"

# ============================================================
# Patch Delft3D build.sh to limit parallelism
# The original uses "make -j" (unlimited), we need "make -j1"
# ============================================================
echo "Patching build.sh to limit parallel jobs..."
sed -i 's/make -j /make -j1 /g' /build/Delft3D/build.sh
echo "build.sh patched"

# Build D-Flow FM
echo "Building dflowfm..."
./build.sh dflowfm --compiler intel21 2>&1 | tee /build/build_dflowfm.log
BUILD_STATUS=${PIPESTATUS[0]}

if [ $BUILD_STATUS -ne 0 ]; then
    echo "================================================"
    echo "DFLOWFM BUILD FAILED with exit code $BUILD_STATUS"
    echo "Check /build/build_dflowfm.log for details"
    echo "================================================"
    exit $BUILD_STATUS
fi

# Build DIMR (Deltares Integrated Model Runner)
echo "Building dimr..."
./build.sh dimr --compiler intel21 2>&1 | tee /build/build_dimr.log
DIMR_STATUS=${PIPESTATUS[0]}

if [ $DIMR_STATUS -ne 0 ]; then
    echo "================================================"
    echo "DIMR BUILD FAILED with exit code $DIMR_STATUS"
    echo "Check /build/build_dimr.log for details"
    echo "================================================"
    exit $DIMR_STATUS
fi

echo "================================================"
echo "Build complete! Binaries in:"
echo "  /build/Delft3D/build_dflowfm/install/bin/"
echo "  /build/Delft3D/build_dimr/install/bin/"
echo "================================================"
