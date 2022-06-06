#
# Copyright (c) 2019 Carnegie Mellon University,
# Copyright (c) 2019 Triad National Security, LLC, as operator of
#     Los Alamos National Laboratory.
#
# All rights reserved.
#
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file. See the AUTHORS file for names of contributors.
#

#
# CMakeLists.txt  build benchmark/testing environment 
# 16-Jul-2020  chuck@ece.cmu.edu
#

#
# general command line config:
#
#   -DCMAKE_INSTALL_PREFIX=/usr/local     # installation prefix
#   -DCMAKE_BUILD_TYPE=RelWithDebInfo     # or Release, Debug, etc.
#      (XXX: currently only applied to cmake-based builds)
#
#   -DUMBRELLA_BUILD_TESTS=ON             # build unit tests?
#   -DUMBRELLA_SKIP_TESTS=OFF             # skip running unit tests?
#
# finding dependencies:
#
#   -DCMAKE_PREFIX_PATH='/pkg'            # look for additional installs here
#
# the following also applies for configure scripts:
#   -DCMAKE_INCLUDE_PATH='/pkg/include'   # extra include directories
#   -DCMAKE_LIBRARY_PATH='/pkg/lib'       # extra library path
#
# note these are all cmake lists (so more than one directory can
# be specified using a semicolon to create a path).
#
# specifying alternate compilers (overrides CC/CXX environment variables):
#   -DCC=/bin/cc
#   -DCXX=/bin/cxx
#
#   you may also use the longer names
#     -DCMAKE_C_COMPILER
#     -DCMAKE_CXX_COMPILER
#
# specifying which mpi to use by pointing at the wrappers:
#   -DMPI_C_COMPILER=/usr/bin/mpicc
#   -DMPI_CXX_COMPILER=/usr/bin/mpicxx
#   -DMPIEXEC=/usr/bin/mpiexec
#

cmake_minimum_required (VERSION 3.0)

#
# put the umbrella scripts in our search path and include umbrella-init
# (umbrella-init needs to run before "project")
#
list (APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/umbrella")
include (umbrella-init)

#
# we don't really use MPICXX for now. The difference between CXX and MPICXX
# is that CXX refers to the MPI C API being usable from C++, whereas MPICXX
# refers to the MPI-2 C++ API that was removed again in MPI-3.
# To enable MPICXX, run umbrella with -DMPI_CXX_SKIP_MPICXX=Off.
#
set (MPI_CXX_SKIP_MPICXX ON CACHE BOOL "True if MPICXX should be skipped")

#
# need to mark project as using C/CXX so we can probe for MPI
# using a compiler that may have been passed in via the command line
# or by using environment vars.
#
project (benchtest-umbrella C CXX)

#
# propagate the MPICXX setting to all cmake subprojects
#
list(APPEND UMBRELLA_CMAKECACHE -DMPI_CXX_SKIP_MPICXX:BOOL=${MPI_CXX_SKIP_MPICXX})

#
# configure umbrella for MPI and pull in the main routines
#
set (UMBRELLA_MPI 1)
include (umbrella-main)

#
# cache variables that control what we build
#
set (CPU     "ON"  CACHE BOOL "Build CPU-related tests")
set (MPI     "ON"  CACHE BOOL "Build MPI-related tests")
set (NET     "ON"  CACHE BOOL "Build network-related tests")
set (NET_IB  "ON"  CACHE BOOL "Build infiniband nework-related tests")
set (NET_IB_MKLIBS "OFF" CACHE BOOL "Build rdma-core libs ourselves")
set (STORAGE "ON"  CACHE BOOL "Build storage-related tests")
set (PDL     "ON"  CACHE BOOL "Build PDL-related tests")

# force these to match the short hand versions
set (UMBRELLA_REQUIRE_RDMALIBS "${NET_IB}" 
     CACHE BOOL "Require rdma libs" FORCE)
set (UMBRELLA_BUILD_RDMALIBS "${NET_IB_MKLIBS}"
     CACHE BOOL "tracks NET_IB_MKLIBS" FORCE)

#
# set git tags to the versions we want to stick to by default...
#
umbrella_opt_default (BMI_TAG "6ea0b78f")             # Jan 2020
umbrella_opt_default (CCI_TAG "3ab663e0")
umbrella_opt_default (IPERF3_TAG "master")
umbrella_opt_default (LIBNL_TAG "master")
umbrella_opt_default (MERCURY_PROGRESSOR_TAG "6892c220") # Oct 2020
umbrella_opt_default (MERCURY_RUNNER_TAG "cbe7a219")  # Apr 2021
umbrella_opt_default (MERCURY_TAG "06a1bf33")         # Jun 2022
umbrella_opt_default (NETPERF_TAG "master")
umbrella_opt_default (NEXUS_RUNNER_TAG "04ee7e8a")    # Apr 2021
umbrella_opt_default (OFI_TAG "1a89deaa")             # Feb 2022
umbrella_opt_default (OSU_MICRO_BENCHMARKS_REPO
          "https://github.com/pdlfs/osu-micro-benchmarks.git")
          # forces a load from git repo
umbrella_opt_default (OSU_MICRO_BENCHMARKS_TAG "v5.6.1")
umbrella_opt_default (PERFTEST_TAG "master")
umbrella_opt_default (RDMA_CORE_TAG "master")

#
# set other configs before we start pulling in the pieces...
#

# note: NA_INITIALLY_ON is only applied as the defaults the first time
# you run cmake.  if you want to reconfigure, change MERCURY_BMI, et al.
umbrella_opt_default (MERCURY_NA_INITIALLY_ON "bmi;cci;ofi;sm")

# setup scripts cache
set (my-scripts-cache "${UMBRELLA_CMAKECACHE}")

if (CPU)
    # lmbench, etc?
endif ()

if (NET)
    include (umbrella/iperf2)
    include (umbrella/iperf3)
    include (umbrella/netperf)
    if (NET_IB)
        include (umbrella/fabtests)
        include (umbrella/opensm)
        include (umbrella/perftest)
        include (umbrella/qperf)
        include (umbrella/rdma-core)
    endif ()
endif ()

if (MPI)
    include (umbrella/osu-micro-benchmarks)
endif ()

if (PDL)
    include (umbrella/deltafs-nexus)
    include (umbrella/deltafs-shuffle)
    include (umbrella/mercury)
    include (umbrella/mercury-progressor)
    include (umbrella/mercury-runner)
    include (umbrella/nexus-runner)
endif ()


#
# scripts -- live here in deltafs-umbrella
#
ExternalProject_Add (scripts
    DOWNLOAD_COMMAND true    # no need to download, comes with umbrella
    SOURCE_DIR ${CMAKE_SOURCE_DIR}/scripts
    CMAKE_CACHE_ARGS "${my-scripts-cache}"

    UPDATE_COMMAND ""
)
