# Dockerfile for Delft3D-FM Compilation
# Based on Ubuntu 22.04 LTS
# Uses Intel OneAPI compilers for Fortran/C++
# Targets Windows hosts via X11 forwarding (WSLg)
#
# ParaView is intentionally installed separately on Windows. The container
# includes ncview for quick inspection through WSLg.
#
# GUI USAGE (Windows):
#   Run docker from a WSL2 terminal where $DISPLAY is set by WSLg:
#   docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix <image>

FROM ubuntu:22.04

# Use bash for all RUN commands — Ubuntu's default /bin/sh is dash which doesn't support 'source'
SHELL ["/bin/bash", "-c"]

# Prevent interactive prompts during apt installs
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Enable universe repo and generate locale
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common locales && \
    add-apt-repository universe && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Build essentials
    gcc \
    g++ \
    make \
    autoconf \
    automake \
    libtool \
    git \
    subversion \
    wget \
    curl \
    gnupg \
    # Required libraries
    zlib1g-dev \
    libexpat1-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libsqlite3-dev \
    sqlite3 \
    libtiff-dev \
    libgtest-dev \
    libgdal-dev \
    uuid-dev \
    # Utilities
    file \
    patch \
    pkg-config \
    python3 \
    python3-pip \
    bzip2 \
    procps \
    patchelf \
    ca-certificates \
    # X11 and GUI dependencies (for visualization tools via X11 forwarding)
    xauth \
    x11-utils \
    libx11-6 \
    libx11-dev \
    libxext6 \
    libxrender1 \
    libxt-dev \
    libgl1 \
    libgl1-mesa-dev \
    libgl1-mesa-dri \
    fontconfig \
    libfreetype6 \
    # Visualization tools for Delft3D output
    ncview \
    # Python scientific stack for scripting and post-processing
    python3-numpy \
    python3-scipy \
    python3-pandas \
    python3-netcdf4 \
    python3-xarray \
    # dbus-x11 needed by some GUI apps (ncview, etc.)
    dbus-x11 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install CMake 3.30+ (required by Delft3D; Ubuntu 22.04 ships 3.22 which is too old)
RUN wget https://github.com/Kitware/CMake/releases/download/v3.30.0/cmake-3.30.0-linux-x86_64.tar.gz && \
    tar -xzf cmake-3.30.0-linux-x86_64.tar.gz -C /opt && \
    ln -s /opt/cmake-3.30.0-linux-x86_64/bin/* /usr/local/bin/ && \
    rm cmake-3.30.0-linux-x86_64.tar.gz

# Add Intel oneAPI repository and import GPG key
RUN wget -qO- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | \
    gpg --dearmor > /usr/share/keyrings/oneapi-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
    > /etc/apt/sources.list.d/oneAPI.list

# Install Intel oneAPI compilers and tools
RUN apt-get update && \
    apt-get install -y \
    intel-oneapi-compiler-fortran-2023.2.0 \
    intel-oneapi-compiler-dpcpp-cpp-and-cpp-classic-2023.2.0 \
    intel-oneapi-mpi-devel-2021.10.0 \
    intel-oneapi-mkl-devel-2023.2.0 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set up Intel oneAPI environment in bashrc
# Ubuntu uses /etc/bash.bashrc (not /etc/bashrc)
RUN echo "source /opt/intel/oneapi/setvars.sh --force" >> /etc/bash.bashrc && \
    echo "export ONEAPI_ROOT=/opt/intel/oneapi" >> /etc/bash.bashrc

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
             -DCMAKE_INSTALL_LIBDIR=lib \
             -DBUILD_SHARED_LIBS=OFF && \
    make -j$(nproc) && \
    make install && \
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
    PATH=/build/Delft3D/build_dimr/install/bin:/opt/netcdf/bin:/opt/hdf5/bin:/opt/petsc/bin:/opt/proj/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# ============================================================
# Clone and build Delft3D-FM
# ============================================================
WORKDIR /build
RUN git clone --branch DIMRset_2.30.17 --depth 1 https://github.com/Deltares/Delft3D.git

# Copy helper scripts
COPY scripts/build_delft3d.sh /build/build_delft3d.sh
COPY scripts/dflowfm.sh       /usr/local/bin/dflowfm
COPY scripts/delft3d-info.sh  /usr/local/bin/delft3d-info
COPY scripts/entrypoint.sh    /usr/local/bin/entrypoint.sh
COPY scripts/verify_container.sh /usr/local/bin/verify-delft3d
RUN chmod +x /build/build_delft3d.sh \
             /usr/local/bin/dflowfm \
             /usr/local/bin/delft3d-info \
             /usr/local/bin/entrypoint.sh \
             /usr/local/bin/verify-delft3d

# Build Delft3D-FM suite
RUN /build/build_delft3d.sh

# Set final working directory
WORKDIR /workspace

# Add helpful message on container start
# Ubuntu uses /etc/bash.bashrc instead of /etc/bashrc
RUN echo 'cat << "BANNER"' >> /etc/bash.bashrc && \
    echo '================================================' >> /etc/bash.bashrc && \
    echo 'Delft3D-FM Container (Ubuntu 22.04)' >> /etc/bash.bashrc && \
    echo '================================================' >> /etc/bash.bashrc && \
    echo 'Quick commands:' >> /etc/bash.bashrc && \
    echo '  delft3d-info         - Show version info' >> /etc/bash.bashrc && \
    echo '  dflowfm <model.mdu>  - Run a D-Flow FM model' >> /etc/bash.bashrc && \
    echo '  dimr <dimr_config.xml> - Run a coupled DIMR model' >> /etc/bash.bashrc && \
    echo '  ncview <file.nc>     - View NetCDF output' >> /etc/bash.bashrc && \
    echo '' >> /etc/bash.bashrc && \
    echo 'GUI on Windows (WSL2 terminal required):' >> /etc/bash.bashrc && \
    echo '  docker run -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix delft3d-fm-ubuntu' >> /etc/bash.bashrc && \
    echo '================================================' >> /etc/bash.bashrc && \
    echo 'BANNER' >> /etc/bash.bashrc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
