# benchtest-umbrella

This is an umbrella repository used to build benchmarks and test programs
that we use.  Umbrella repositories require cmake to build.

# configuration

All configuration is done using cmake variables.  Key variables:
```
CMAKE_INSTALL_PREFIX - where to install
CMAKE_PREFIX_PATH - where to look for prebuilt programs/libs we need
```

Variables can be set using the "-D" flag to cmake.  For example:
```
cmake -DCMAKE_INSTALL_PREFIX=/home/benchtest ...
```

Currently by default we build everything.  We have some cmake flags
that allow you to turn off parts of the build.  See the "cache variables
that control what we build" section of the CMakeLists.txt file.

# bootstrapping

The main issue with bootstrapping is Infiniband/RDMA support.  If
you do not need this, you can set NET_IB=OFF and not worry about
bootstrapping.

There are several issues related to Infiniband/RDMA:
* does your system come with the rdma-core libs (e.g. libibverbs.so) installed?
* does your hardware have an alternate interface to ibverbs that is more efficient?
* do you have an MPI install that is built with the transport you want?

You need the proper transport libs installed for optimal performance.
Your MPI install must be linked to these libs in order to take advantage
of them.  The umbrella code assumes that you've got the version of
MPI that you want to use already installed.

If your system has the optimial transport libs installed and the
provided MPI is linked to them, then you are good.  If not, you may
be able to use the system provided package manager (e.g. "apt" or "yum")
to install the libs and an MPI that uses them.  Or you can use the
umbrealla bootstrap to build and install the libs and MPI prior to
building the main umbrella.

## Using package manager

(this is not complete)

For UBUNTU with libibverbs, use apt to install:  librdmacm-dev,
libibumad-dev, libibverbs-dev.  UBUNTU doesn't have an MVAPICH package.
The OpenMPI package might use the rmda-core libs?

For CENTOS with libibverbs, use yum to install: librdmacm.x86_64,
libibumad.x86_64, libibverbs.x86_64.   Also mvapich23.x86_64.

## Building with the umbrella bootstrap

You have two options: install the bootstrap in its own prefix directory
or install the bootstrap in the same directory prefix as all the benchtest
software.  Keeping the bootstrap in its own prefix directory allows a single
bootstrap install to be shared by multiple benchtest installs, but then
you need to specify that directory as part of the CMAKE_PREFIX_PATH
of the benchtest build.

# Example build commands

Under the PDL UBUNTU18 Emulab image, using the bootstrap:

```
git clone https://github.com/pdlfs/benchtest-umbrella
mkdir -p benchtest-umbrella/bootstrap/build
cd benchtest-umbrella/bootstrap/build

# set $bootprefix to where you want install the bootstrap
cmake -DUMBRELLA_BUILD_RDMALIBS=ON -DCMAKE_INSTALL_PREFIX=$bootprefix \
    -DBOOTSTRAP=mvapich ..
# will build rdma-core and mvapich
make -j

# now build main bootstrap in $prefix
# note: CMAKE_PREFIX_PATH needed only if $bootprefix != $prefix
cd ../..
mkdir build
cd build
cmake -DCMAKE_PREFIX_PATH=$bootprefix -DCMAKE_INSTALL_PREFIX=$prefix ..
make -j
```

The CENTOS7 Emulab image is similiar, except you need to use "cmake3"
instead of "cmake" (use "yum install" to add it if isn't present).

To build the bootstrap MPI using psm as an alternate interface,
add "-DMVAPICH_DEVICE=ch3:psm" to the bootstrap cmake config (the
default is to use ibverbs).

Once installed, you will likely want to add $bootprefix/{bin,sbin} and
$prefix/{bin,sbin} to your shell's path.
