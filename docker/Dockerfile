# Dockerfile for Delft3D-FM Compilation
# Based on Rocky Linux 8 (CentOS 8 successor, actively maintained)
# Uses Intel OneAPI compilers for Fortran/C++

FROM rockylinux:8

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Enable PowerTools repository (has additional dev packages)
RUN dnf install -y dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf -y update

# Install base dependencies via dnf
RUN dnf -y install \
    # Build essentials
    gcc \
    gcc-c++ \
    make \
    autoconf \
    automake \
    libtool \
    git \
    subversion \
    wget \
    curl \
    # Required libraries
    zlib-devel \
    expat-devel \
    libxml2-devel \
    libcurl-devel \
    # HDF5 (will also build from source for consistency)
    hdf5-devel \
    # Utilities
    which \
    file \
    patch \
    pkg-config \
    cmake \
    python3 \
    bzip2 \
    && dnf clean all

# Add Intel oneAPI repository
RUN tee /etc/yum.repos.d/oneAPI.repo > /dev/null <<EOF
[oneAPI]
name=Intel oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

# Install Intel oneAPI compilers and tools
# Using Intel Fortran 2021.4 (compatible with Delft3D build scripts)
RUN dnf -y install \
    intel-oneapi-compiler-fortran-2021.4.0 \
    intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2021.4.0 \
    intel-oneapi-mpi-devel-2021.4.0 \
    intel-oneapi-mkl-devel-2021.4.0 \
    && dnf clean all

# Set up Intel oneAPI environment in bashrc
RUN echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bashrc && \
    echo "export ONEAPI_ROOT=/opt/intel/oneapi" >> /etc/bashrc

# Create working directories
RUN mkdir -p /opt/delft3d /build

# Set working directory
WORKDIR /build

# Clone Delft3D repository
RUN git clone https://github.com/Deltares/Delft3D.git

# Build NetCDF-C with Intel compilers
# Delft3D requires NetCDF compiled with the same compiler
WORKDIR /build/netcdf

# Download and build HDF5 first (for NetCDF dependency)
RUN wget https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.12/hdf5-1.12.2/src/hdf5-1.12.2.tar.gz && \
    tar -xzf hdf5-1.12.2.tar.gz && \
    cd hdf5-1.12.2 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    CC=icc CXX=icpc FC=ifort CFLAGS="-O3 -fPIC" CXXFLAGS="-O3 -fPIC" FCFLAGS="-O3 -fPIC" \
    ./configure --prefix=/opt/hdf5 \
                --enable-fortran \
                --enable-cxx \
                --enable-parallel=no && \
    make -j$(nproc) && \
    make install

# Download and build NetCDF-C
RUN wget https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz && \
    tar -xzf netcdf-c-4.9.2.tar.gz && \
    cd netcdf-c-4.9.2 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    export LD_LIBRARY_PATH=/opt/hdf5/lib:$LD_LIBRARY_PATH && \
    CC=icc CFLAGS="-O3 -fPIC" \
    CPPFLAGS="-I/opt/hdf5/include" \
    LDFLAGS="-L/opt/hdf5/lib" \
    ./configure --prefix=/opt/netcdf \
                --disable-dap \
                --disable-byterange && \
    make -j$(nproc) && \
    make install

# Download and build NetCDF-Fortran
RUN wget https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz && \
    tar -xzf netcdf-fortran-4.6.1.tar.gz && \
    cd netcdf-fortran-4.6.1 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:$LD_LIBRARY_PATH && \
    CC=icc FC=ifort CFLAGS="-O3 -fPIC" FCFLAGS="-O3 -fPIC" \
    CPPFLAGS="-I/opt/netcdf/include -I/opt/hdf5/include" \
    LDFLAGS="-L/opt/netcdf/lib -L/opt/hdf5/lib" \
    ./configure --prefix=/opt/netcdf && \
    make -j$(nproc) && \
    make install

# Install PETSc (required for some Delft3D-FM features)
WORKDIR /build/petsc
RUN wget https://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-3.19.4.tar.gz && \
    tar -xzf petsc-3.19.4.tar.gz && \
    cd petsc-3.19.4 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    ./configure --prefix=/opt/petsc \
                --with-cc=icc \
                --with-cxx=icpc \
                --with-fc=ifort \
                --download-fblaslapack=1 \
                --with-debugging=0 \
                COPTFLAGS='-O3' \
                FOPTFLAGS='-O3' \
                CXXOPTFLAGS='-O3' && \
    make PETSC_DIR=/build/petsc/petsc-3.19.4 PETSC_ARCH=arch-linux-c-opt all && \
    make PETSC_DIR=/build/petsc/petsc-3.19.4 PETSC_ARCH=arch-linux-c-opt install

# Install METIS (mesh partitioning library)
WORKDIR /build/metis
RUN wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/metis-5.1.0.tar.gz && \
    tar -xzf metis-5.1.0.tar.gz && \
    cd metis-5.1.0 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    make config prefix=/opt/metis cc=icc && \
    make && \
    make install

# Install PROJ (coordinate transformation library)
WORKDIR /build/proj
RUN wget https://download.osgeo.org/proj/proj-9.4.0.tar.gz && \
    tar -xzf proj-9.4.0.tar.gz && \
    cd proj-9.4.0 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/opt/proj \
             -DCMAKE_C_COMPILER=icc \
             -DCMAKE_CXX_COMPILER=icpc \
             -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install

# Set up environment for Delft3D build
ENV NETCDF_DIR=/opt/netcdf \
    HDF5_DIR=/opt/hdf5 \
    PETSC_DIR=/opt/petsc \
    METIS_DIR=/opt/metis \
    PROJ_DIR=/opt/proj \
    PKG_CONFIG_PATH=/opt/netcdf/lib/pkgconfig:/opt/hdf5/lib/pkgconfig:/opt/petsc/lib/pkgconfig:/opt/proj/lib/pkgconfig:$PKG_CONFIG_PATH \
    LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/proj/lib:$LD_LIBRARY_PATH \
    PATH=/opt/netcdf/bin:/opt/hdf5/bin:/opt/petsc/bin:/opt/proj/bin:$PATH

# Build Delft3D-FM
WORKDIR /build/Delft3D

# Create a build wrapper script
RUN echo '#!/bin/bash' > /build/build_delft3d.sh && \
    echo 'set -e' >> /build/build_delft3d.sh && \
    echo 'echo "================================================"' >> /build/build_delft3d.sh && \
    echo 'echo "Building Delft3D-FM Suite"' >> /build/build_delft3d.sh && \
    echo 'echo "================================================"' >> /build/build_delft3d.sh && \
    echo 'source /opt/intel/oneapi/setvars.sh --force' >> /build/build_delft3d.sh && \
    echo 'cd /build/Delft3D' >> /build/build_delft3d.sh && \
    echo 'export NETCDF_DIR=/opt/netcdf' >> /build/build_delft3d.sh && \
    echo 'export HDF5_DIR=/opt/hdf5' >> /build/build_delft3d.sh && \
    echo 'export PETSC_DIR=/opt/petsc' >> /build/build_delft3d.sh && \
    echo 'export METIS_DIR=/opt/metis' >> /build/build_delft3d.sh && \
    echo 'export PROJ_DIR=/opt/proj' >> /build/build_delft3d.sh && \
    echo './build.sh fm-suite --compiler intel21 2>&1 | tee /build/build.log' >> /build/build_delft3d.sh && \
    echo 'echo "================================================"' >> /build/build_delft3d.sh && \
    echo 'echo "Build complete! Binaries in:"' >> /build/build_delft3d.sh && \
    echo 'echo "  /build/Delft3D/build_fm-suite/install/bin/"' >> /build/build_delft3d.sh && \
    echo 'echo "================================================"' >> /build/build_delft3d.sh && \
    chmod +x /build/build_delft3d.sh

# Optional: Uncomment to build during image creation (slower build, but ready-to-use image)
# RUN /build/build_delft3d.sh

# Set final working directory
WORKDIR /workspace

# Add entrypoint script for easy model execution
RUN echo '#!/bin/bash' > /usr/local/bin/dflowfm && \
    echo 'source /opt/intel/oneapi/setvars.sh --force > /dev/null 2>&1' >> /usr/local/bin/dflowfm && \
    echo 'export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/proj/lib:$LD_LIBRARY_PATH' >> /usr/local/bin/dflowfm && \
    echo 'INSTALL_BIN="/build/Delft3D/build_fm-suite/install/bin"' >> /usr/local/bin/dflowfm && \
    echo 'if [ -f "$INSTALL_BIN/run_dflowfm.sh" ]; then' >> /usr/local/bin/dflowfm && \
    echo '    exec "$INSTALL_BIN/run_dflowfm.sh" "$@"' >> /usr/local/bin/dflowfm && \
    echo 'else' >> /usr/local/bin/dflowfm && \
    echo '    echo "ERROR: Delft3D not compiled yet. Run: /build/build_delft3d.sh"' >> /usr/local/bin/dflowfm && \
    echo '    exit 1' >> /usr/local/bin/dflowfm && \
    echo 'fi' >> /usr/local/bin/dflowfm && \
    chmod +x /usr/local/bin/dflowfm

# Create a version info script
RUN echo '#!/bin/bash' > /usr/local/bin/delft3d-info && \
    echo 'source /opt/intel/oneapi/setvars.sh --force' >> /usr/local/bin/delft3d-info && \
    echo 'echo "================================================"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "Delft3D-FM Container Information"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "================================================"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "OS:           Rocky Linux 8"' >> /usr/local/bin/delft3d-info && \
    echo 'echo -n "Compiler:     "; ifort --version | head -n1' >> /usr/local/bin/delft3d-info && \
    echo 'echo -n "NetCDF-C:     "; nc-config --version' >> /usr/local/bin/delft3d-info && \
    echo 'echo -n "NetCDF-F:     "; nf-config --version' >> /usr/local/bin/delft3d-info && \
    echo 'echo "HDF5:         1.12.2"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "PETSc:        3.19.4"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "METIS:        5.1.0"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "PROJ:         9.4.0"' >> /usr/local/bin/delft3d-info && \
    echo 'echo "================================================"' >> /usr/local/bin/delft3d-info && \
    chmod +x /usr/local/bin/delft3d-info

# Add helpful message on container start
RUN echo 'cat << "EOF"' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'Delft3D-FM Container (Rocky Linux 8)' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'Quick commands:' >> /etc/bashrc && \
    echo '  delft3d-info         - Show version info' >> /etc/bashrc && \
    echo '  /build/build_delft3d.sh - Compile Delft3D-FM' >> /etc/bashrc && \
    echo '  dflowfm <model.mdu>  - Run a model' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'EOF' >> /etc/bashrc

CMD ["/bin/bash"]
