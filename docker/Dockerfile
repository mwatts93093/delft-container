# Dockerfile for Delft3D-FM Compilation
# Based on Rocky Linux 8 (CentOS 8 successor, actively maintained)
# Uses Intel OneAPI compilers for Fortran/C++
# Targets Windows hosts via X11 forwarding
#
# GUI USAGE (Windows):
#   Option 1 - WSL2 + WSLg (Windows 11 / Win10 21H2+, Docker Desktop WSL2 backend):
#     WSLg provides an X server automatically; GUI apps display natively.
#     docker run -e DISPLAY=$DISPLAY <image>
#
#   Option 2 - VcXsrv or MobaXterm (any Windows):
#     Launch VcXsrv with "Disable access control" checked, then:
#     docker run -e DISPLAY=host.docker.internal:0.0 <image>

FROM rockylinux:8

# Set environment variables
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Enable PowerTools and EPEL repositories and install all system dependencies in one layer
RUN dnf install -y dnf-plugins-core epel-release && \
    dnf config-manager --set-enabled powertools && \
    dnf -y update && \
    dnf -y install \
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
    sqlite-devel \
    libtiff-devel \
    gtest-devel \
    gdal-devel \
    libuuid-devel \
    # Utilities
    which \
    file \
    patch \
    pkg-config \
    python3 \
    bzip2 \
    procps-ng \
    patchelf \
    ca-certificates \
    # X11 and GUI dependencies (for visualization tools via X11 forwarding)
    xorg-x11-xauth \
    xorg-x11-utils \
    libX11 \
    libX11-devel \
    libXext \
    libXrender \
    libXt-devel \
    mesa-libGL \
    mesa-libGL-devel \
    mesa-dri-drivers \
    fontconfig \
    freetype \
    qt5-qtbase \
    qt5-qtbase-gui \
    qt5-qtsvg \
    # Visualization tools for Delft3D output
    ncview \
    paraview \
    python3-numpy \
    && dnf clean all

# Install CMake 3.30+ (required by Delft3D)
RUN wget https://github.com/Kitware/CMake/releases/download/v3.30.0/cmake-3.30.0-linux-x86_64.tar.gz && \
    tar -xzf cmake-3.30.0-linux-x86_64.tar.gz -C /opt && \
    ln -s /opt/cmake-3.30.0-linux-x86_64/bin/* /usr/local/bin/ && \
    rm cmake-3.30.0-linux-x86_64.tar.gz

# Add Intel oneAPI repository and import GPG key explicitly
# (repo_gpgcheck disabled because Intel's current key doesn't cover older 2021.4 packages)
RUN rpm --import https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
    tee /etc/yum.repos.d/oneAPI.repo > /dev/null <<EOF
[oneAPI]
name=Intel oneAPI repository
baseurl=https://yum.repos.intel.com/oneapi
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
EOF

# Install Intel oneAPI compilers and tools
# Using Intel oneAPI 2023.x which has better Fortran 2008 support
# Classic compilers (icc/icpc/ifort) are still available in 2023.x
RUN dnf -y install \
    intel-oneapi-compiler-fortran-2023.2.0 \
    intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.0 \
    intel-oneapi-mpi-devel-2021.10.0 \
    intel-oneapi-mkl-devel-2023.2.0 \
    && dnf clean all

# Set up Intel oneAPI environment in bashrc
RUN echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bashrc && \
    echo "export ONEAPI_ROOT=/opt/intel/oneapi" >> /etc/bashrc

# Create working directories
RUN mkdir -p /opt/delft3d /build

# ============================================================
# Build HDF5 from source with Intel compilers
# ============================================================
WORKDIR /build/netcdf
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
    make install && \
    cd /build && rm -rf /build/netcdf/hdf5-1.12.2 /build/netcdf/hdf5-1.12.2.tar.gz

# ============================================================
# Build NetCDF-C
# ============================================================
RUN wget --no-check-certificate https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz && \
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
    make install && \
    cd /build && rm -rf /build/netcdf/netcdf-c-4.9.2 /build/netcdf/netcdf-c-4.9.2.tar.gz

# ============================================================
# Build NetCDF-Fortran
# ============================================================
RUN wget --no-check-certificate https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz && \
    tar -xzf netcdf-fortran-4.6.1.tar.gz && \
    cd netcdf-fortran-4.6.1 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    export LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:$LD_LIBRARY_PATH && \
    CC=icc FC=ifort CFLAGS="-O3 -fPIC" FCFLAGS="-O3 -fPIC" \
    CPPFLAGS="-I/opt/netcdf/include -I/opt/hdf5/include" \
    LDFLAGS="-L/opt/netcdf/lib -L/opt/hdf5/lib" \
    ./configure --prefix=/opt/netcdf && \
    make -j$(nproc) && \
    make install && \
    cd /build && rm -rf /build/netcdf/netcdf-fortran-4.6.1 /build/netcdf/netcdf-fortran-4.6.1.tar.gz

# ============================================================
# Build PETSc (required for some Delft3D-FM features)
# ============================================================
WORKDIR /build/petsc
RUN wget https://ftp.mcs.anl.gov/pub/petsc/release-snapshots/petsc-3.19.4.tar.gz && \
    tar -xzf petsc-3.19.4.tar.gz && \
    cd petsc-3.19.4 && \
    source /opt/intel/oneapi/setvars.sh --force && \
    ./configure --prefix=/opt/petsc \
                --with-cc=mpiicc \
                --with-cxx=mpiicpc \
                --with-fc=mpiifort \
                --download-fblaslapack=1 \
                --with-debugging=0 \
                COPTFLAGS='-O3' \
                FOPTFLAGS='-O3' \
                CXXOPTFLAGS='-O3' && \
    make PETSC_DIR=/build/petsc/petsc-3.19.4 PETSC_ARCH=arch-linux-c-opt all && \
    make PETSC_DIR=/build/petsc/petsc-3.19.4 PETSC_ARCH=arch-linux-c-opt install && \
    cd /build && rm -rf /build/petsc/petsc-3.19.4 /build/petsc/petsc-3.19.4.tar.gz

# ============================================================
# Build METIS 5.2.1 (mesh partitioning library)
# Sourced from GitHub (KarypisLab); requires GKlib as a dependency
# ============================================================
WORKDIR /build/metis
RUN wget https://github.com/KarypisLab/GKlib/archive/refs/heads/master.tar.gz -O gklib.tar.gz && \
    tar -xzf gklib.tar.gz && \
    wget https://github.com/KarypisLab/METIS/archive/refs/tags/v5.2.1.tar.gz -O metis-5.2.1.tar.gz && \
    tar -xzf metis-5.2.1.tar.gz && \
    source /opt/intel/oneapi/setvars.sh --force && \
    cd GKlib-master && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/opt/gklib \
             -DCMAKE_C_COMPILER=icc \
             -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_SHARED_LIBS=ON && \
    make -j$(nproc) && \
    make install && \
    cp /opt/gklib/lib64/libGKlib.a /opt/gklib/lib/ && \
    cd /build/metis/METIS-5.2.1 && \
    make config prefix=/opt/metis gklib_path=/opt/gklib cc=icc && \
    make && \
    make install && \
    cd /build && rm -rf /build/metis/METIS-5.2.1 /build/metis/GKlib-master /build/metis/*.tar.gz

# ============================================================
# Build PROJ (coordinate transformation library)
# ============================================================
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
    make install && \
    cd /build && rm -rf /build/proj/proj-9.4.0 /build/proj/proj-9.4.0.tar.gz

# ============================================================
# Set up environment for Delft3D build and runtime
# ============================================================
ENV NETCDF_DIR=/opt/netcdf \
    HDF5_DIR=/opt/hdf5 \
    PETSC_DIR=/opt/petsc \
    METIS_DIR=/opt/metis \
    PROJ_DIR=/opt/proj \
    PKG_CONFIG_PATH=/opt/netcdf/lib/pkgconfig:/opt/hdf5/lib/pkgconfig:/opt/petsc/lib/pkgconfig:/opt/proj/lib/pkgconfig \
    LD_LIBRARY_PATH=/opt/netcdf/lib:/opt/hdf5/lib:/opt/petsc/lib:/opt/metis/lib:/opt/gklib/lib:/opt/proj/lib \
    PATH=/opt/netcdf/bin:/opt/hdf5/bin:/opt/petsc/bin:/opt/proj/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ============================================================
# Clone and build Delft3D-FM
# ============================================================
WORKDIR /build
RUN git clone --branch DIMRset_2.30.17 --depth 1 https://github.com/Deltares/Delft3D.git

# Copy helper scripts
COPY scripts/build_delft3d.sh /build/build_delft3d.sh
COPY scripts/dflowfm.sh      /usr/local/bin/dflowfm
COPY scripts/delft3d-info.sh  /usr/local/bin/delft3d-info
COPY scripts/entrypoint.sh    /usr/local/bin/entrypoint.sh
RUN chmod +x /build/build_delft3d.sh \
             /usr/local/bin/dflowfm \
             /usr/local/bin/delft3d-info \
             /usr/local/bin/entrypoint.sh

# Build Delft3D-FM suite
RUN /build/build_delft3d.sh

# Set final working directory
WORKDIR /workspace

# Add helpful message on container start
RUN echo 'cat << "BANNER"' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'Delft3D-FM Container (Rocky Linux 8)' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'Quick commands:' >> /etc/bashrc && \
    echo '  delft3d-info         - Show version info' >> /etc/bashrc && \
    echo '  dflowfm <model.mdu>  - Run a model' >> /etc/bashrc && \
    echo '  paraview             - Launch ParaView' >> /etc/bashrc && \
    echo '  ncview <file.nc>     - View NetCDF output' >> /etc/bashrc && \
    echo '' >> /etc/bashrc && \
    echo 'GUI on Windows (X11 forwarding):' >> /etc/bashrc && \
    echo '  WSL2/WSLg:  docker run -e DISPLAY=$DISPLAY <image>' >> /etc/bashrc && \
    echo '  VcXsrv:     docker run -e DISPLAY=host.docker.internal:0.0 <image>' >> /etc/bashrc && \
    echo '================================================' >> /etc/bashrc && \
    echo 'BANNER' >> /etc/bashrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
