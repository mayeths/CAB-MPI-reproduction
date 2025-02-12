#!/bin/bash
# Replace "REMOTE" and "WORKSPACE_PATH" to somewhere in the following code
# 5 steps

#------- Step 0: Download files (on local machine)
mkdir ./cab_workspace
cd ./cab_workspace
### old building tools
mkdir ./cab_essential
wget -P ./cab_essential https://ftp.gnu.org/gnu/m4/m4-1.4.19.tar.gz
wget -P ./cab_essential https://ftp.gnu.org/gnu/autoconf/autoconf-2.67.tar.gz
wget -P ./cab_essential https://ftp.gnu.org/gnu/libtool/libtool-2.4.7.tar.gz
wget -P ./cab_essential https://ftp.gnu.org/gnu/automake/automake-1.15.1.tar.gz
wget -P ./cab_essential https://github.com/numactl/numactl/releases/download/v2.0.19/numactl-2.0.19.tar.gz
### glibc, pip
# git clone --single-branch --branch pip-coll --depth 1 https://github.com/KaimingOuyang/PiP-glibc ./cab_glibc
git clone --single-branch --branch pip-glibc --depth 1 https://github.com/KaimingOuyang/PiP-glibc ./cab_glibc
git clone --single-branch --branch pip-modified --depth 1 https://github.com/KaimingOuyang/PiP.git ./cab_pip
### mpich
git clone --single-branch --branch rebase-pip-pingpong-original --depth 1 https://github.com/KaimingOuyang/mpich-pip.git ./mpich-pingpong-original-bdw
git clone --single-branch --branch rebase-pip-throughput-aware --depth 1 https://github.com/KaimingOuyang/mpich-pip.git ./mpich-throughput-aware-bdw
git clone --single-branch --branch pip-coll-double-copy --depth 1 https://github.com/KaimingOuyang/mpich-pip.git ./mpich-pip-coll-double-copy
# Some submodules are missing on the internet, so we only manually init and update essential submodules
cd mpich-pingpong-original-bdw
git submodule update --init src/hwloc src/izem src/mpid/ch4/netmod/ucx/ucx src/mpid/ch4/netmod/ofi/libfabric
cd ..
cd mpich-throughput-aware-bdw
git submodule update --init src/hwloc src/izem src/mpid/ch4/netmod/ucx/ucx src/mpid/ch4/netmod/ofi/libfabric
cd ..
cd mpich-pip-coll-double-copy
git submodule update --init modules/hwloc modules/izem modules/ucx modules/libfabric modules/yaksa modules/json-c
cd ..
### app
git clone https://github.com/KaimingOuyang/miniGhost ./miniGhost
git clone https://github.com/KaimingOuyang/BSPMM ./BSPMM
###
file cab_essential cab_glibc cab_pip mpich-pingpong-original-bdw mpich-pip-coll-double-copy mpich-throughput-aware-bdw miniGhost BSPMM
rsync -av cab_essential cab_glibc cab_pip mpich-pingpong-original-bdw mpich-pip-coll-double-copy mpich-throughput-aware-bdw miniGhost BSPMM REMOTE:WORKSPACE_PATH

ssh REMOTE
cd WORKSPACE_PATH

#------- Step 1: Build cab_essential (on working machine)
export cab_workspace=$(realpath WORKSPACE_PATH)
export cab_essential=$(realpath $cab_workspace/cab_essential)
export cab_glibc=$(realpath $cab_workspace/cab_glibc)
export cab_pip=$(realpath $cab_workspace/cab_pip)
export mpich_pingpong_original_bdw=$(realpath $cab_workspace/mpich-pingpong-original-bdw)
export mpich_throughput_aware_bdw=$(realpath $cab_workspace/mpich-throughput-aware-bdw)
export mpich_pip_coll_double_copy=$(realpath $cab_workspace/mpich-pip-coll-double-copy)
export miniGhost=$(realpath $cab_workspace/miniGhost)
export BSPMM=$(realpath $cab_workspace/BSPMM)
file $cab_essential $cab_glibc $cab_pip $mpich_pingpong_original_bdw $mpich_throughput_aware_bdw $mpich_pip_coll_double_copy $miniGhost $BSPMM

module purge # remove all loaded modules (compilers, libraries, etc.) to get clean environment
gcc_version=`gcc -v 2>&1 | grep "gcc version" | awk '{print $3}'`
if [ "${gcc_version}" != "4.8.5" ]; then
    echo "please use gcc 4.8.5 version"
fi

cd $cab_essential
tar -xf m4-1.4.19.tar.gz
tar -xf autoconf-2.67.tar.gz
tar -xf libtool-2.4.7.tar.gz
tar -xf automake-1.15.1.tar.gz
tar -xf numactl-2.0.19.tar.gz

mkdir $cab_essential/install-dir
export PATH=$(realpath -m $cab_essential/install-dir/bin):$PATH
export LD_LIBRARY_PATH=$(realpath -m $cab_essential/install-dir/lib):$LD_LIBRARY_PATH
### m4-1.4.19
cd $cab_essential/m4-1.4.19
./configure --prefix=$(realpath $cab_essential/install-dir)
make -j
make install
### autoconf-2.67
cd $cab_essential/autoconf-2.67
./configure --prefix=$(realpath $cab_essential/install-dir)
make -j
make install
### libtool-2.4.7
cd $cab_essential/libtool-2.4.7
./configure --prefix=$(realpath $cab_essential/install-dir)
make -j
make install
### automake-1.15.1
cd $cab_essential/automake-1.15.1
./configure --prefix=$(realpath $cab_essential/install-dir)
make -j
make install
### numactl-2.0.19
cd $cab_essential/numactl-2.0.19
./configure --prefix=$(realpath $cab_essential/install-dir)
make -j
make install
#
cd $cab_essential/install-dir
ls -1 bin/m4 bin/autoconf bin/libtool bin/automake lib/libnuma.so

#------- Step 2: Build cab_glibc
cd $cab_glibc
uname -r # Get linux version, e.g., 3.10.0
vim build.sh # Change --enable-kernel=2.6.32 of "$1/configure" line, for example to the following line:
# $1/configure --prefix=$2 CC="${CC}" CXX="${CXX}" "CFLAGS=${CFLAGS} ${opt_mtune} -fasynchronous-unwind-tables -DNDEBUG -g -O3 -fno-asynchronous-unwind-tables" --enable-add-ons=${opt_add_ons} --with-headers=/usr/include --enable-kernel=3.10.0 --enable-bind-now --build=${opt_build} ${opt_multi_arch} --enable-obsolete-rpc --disable-profile
mkdir build
cd build
cp ../build.sh .
./build.sh $(realpath ..) $(realpath ../install-dir) 2>&1 | tee build.log
ls ../install-dir/lib/libc.so.6

#------- Step 3: Build cab_pip
cd $cab_pip
./configure --prefix=$(realpath ./install-dir) --with-glibc-libdir=$cab_glibc/install-dir/lib
make CC=gcc FC=gfortran CXX=g++ -j 4
make install
cd ./install-dir/bin
./piplnlibs

#------- Step 4: Build mpich
export PATH=$(realpath $cab_essential/install-dir/bin):$PATH
export PATH=$(realpath $cab_pip/install-dir/bin):$PATH
export LD_LIBRARY_PATH=$(realpath $cab_essential/install-dir/lib):$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$(realpath $cab_pip/install-dir/lib):$LD_LIBRARY_PATH

# (1) pip-coll-double-copy (mpich-pip-coll-double-copy)
cd $mpich_pip_coll_double_copy
./autogen.sh # It's fine if "Patching libtool.m4 for compatibility with IBM XL Fortran compilers...1 out of 1 hunk FAILED"
./configure CC=gcc CXX=g++ FC=gfortran \
    MPICHLIB_CFLAGS="-g -I$cab_essential/install-dir/include -Wl,--dynamic-linker=$cab_glibc/install-dir/lib/ld-2.17.so" \
    LDFLAGS="-Wl,--no-as-needed -ldl -L$cab_essential/install-dir/lib -lnuma" \
    --with-device=ch4:ofi --with-libfabric=embedded --enable-ch4-netmod-inline=no --enable-ch4-shm-inline=no \
    --with-pip-prefix=${cab_pip}/install-dir --with-ch4-shmmods=pip \
    --prefix=$(realpath ./install-dir)
make clean
make -j 32
make install

# (2) rebase-pip-throughput-aware (mpich-throughput-aware-bdw)
cd $mpich_throughput_aware_bdw
./autogen.sh # It's fine if "Patching libtool.m4 for compatibility with IBM XL Fortran compilers...1 out of 1 hunk FAILED"
./configure CC=gcc CXX=g++ FC=gfortran \
    MPICHLIB_CFLAGS="-DMPIDI_PIP_SHM_GET_STEALING -DENABLE_DYNAMIC_CHUNK -DMPIDI_PIP_SHM_ACC_STEALING -DMPIDI_PIP_OFI_ACC_STEALING -DMPIDI_PIP_STEALING_ENABLE -DENABLE_CONTIG_STEALING -DENABLE_NON_CONTIG_STEALING -DENABLE_OFI_STEALING -DENABLE_PARTNER_STEALING -g -I$cab_essential/install-dir/include -Wl,--dynamic-linker=$cab_glibc/install-dir/lib/ld-2.17.so" \
    LDFLAGS="-Wl,--no-as-needed -ldl -L$cab_essential/install-dir/lib -lnuma" \
    --with-device=ch4:ofi --with-libfabric=embedded --enable-ch4-netmod-inline=no --enable-ch4-shm-inline=no \
    --with-pip-prefix=${cab_pip}/install-dir --with-ch4-shmmods=pip \
    --prefix=$(realpath ./install-dir)
make clean
make -j 32
make install

# (3) rebase-pip-pingpong-original (mpich-pingpong-original-bdw)
cd $mpich_pingpong_original_bdw
./autogen.sh # It's fine if "Patching libtool.m4 for compatibility with IBM XL Fortran compilers...1 out of 1 hunk FAILED"
./configure CC=gcc CXX=g++ FC=gfortran \
    MPICHLIB_CFLAGS="-g -I$cab_essential/install-dir/include -Wl,--dynamic-linker=$cab_glibc/install-dir/lib/ld-2.17.so" \
    LDFLAGS="-Wl,--no-as-needed -ldl -L$cab_essential/install-dir/lib -lnuma" \
    --with-device=ch4:ofi --with-libfabric=embedded --enable-ch4-netmod-inline=no --enable-ch4-shm-inline=no \
    --with-pip-prefix=${cab_pip}/install-dir --with-ch4-shmmods=pip \
    --prefix=$(realpath ./install-dir)
make clean
make -j 32
make install


#------- Step 5: Run
cd $miniGhost
module purge
cd ref
vim Makefile # Add "-fPIE -pie -rdynamic -pthread -g" to CFLAGS and FFLAGS, for example to the following line:
# CFLAGS = $(PROTOCOL) -fPIE -pie -rdynamic -pthread -g
# FFLAGS = $(PROTOCOL) -fPIE -pie -rdynamic -pthread -g

###### Select one of the mpich
# (1) pip-coll-double-copy (mpich-pip-coll-double-copy)
export PATH=$mpich_pip_coll_double_copy/install-dir/bin:$PATH
export LD_LIBRARY_PATH=$mpich_pip_coll_double_copy/install-dir/lib:$LD_LIBRARY_PATH
# (2) rebase-pip-throughput-aware (mpich-throughput-aware-bdw)
export PATH=$mpich_throughput_aware_bdw/install-dir/bin:$PATH
export LD_LIBRARY_PATH=$mpich_throughput_aware_bdw/install-dir/lib:$LD_LIBRARY_PATH
# (3) rebase-pip-pingpong-original (mpich-pingpong-original-bdw)
export PATH=$mpich_pingpong_original_bdw/install-dir/bin:$PATH
export LD_LIBRARY_PATH=$mpich_pingpong_original_bdw/install-dir/lib:$LD_LIBRARY_PATH

make clean
make OPT_F="-fPIE -pie -rdynamic -pthread -O3 -g"
mkdir -p timelog
export MINIGHOST_OUT=original-speedup.out
mpirun -n 64 miniGhost.x --npx 4 --npy 4 --npz 4 --num_vars 7 --nx 64 --ny 64 --nz 64 --stencil 23 --num_tsteps 6 --report_perf 1


#------- Example output of step 5
# (1) pip-coll-double-copy (mpich-pip-coll-double-copy) success
"""
Current Step    1, Total Step    6
Current Step    2, Total Step    6
Current Step    3, Total Step    6
Current Step    4, Total Step    6
Current Step    5, Total Step    6
Current Step    6, Total Step    6
 Computation within error tolerance.
  Reductions (to all) per time step
     Number:                     7.000E+00
           Total counts/bytes per time step:   7.000E+00   5.600E+01
       Min, max counts/bytes per time step:    1.000E+00,    8.000E+00;    1.000E+00,    8.000E+00
 ================== End report ===================
"""
# (2) rebase-pip-throughput-aware (mpich-throughput-aware-bdw) failed
"""
[mpiexec@dn004] control_cb (pm/pmiserv/pmiserv_cb.c:207): assert (!closed) failed
[mpiexec@dn004] HYDT_dmxu_poll_wait_for_event (tools/demux/demux_poll.c:77): callback returned error status
[mpiexec@dn004] HYD_pmci_wait_for_completion (pm/pmiserv/pmiserv_pmci.c:195): error waiting for event
[mpiexec@dn004] main (ui/mpich/mpiexec.c:336): process manager error waiting for completion
"""
# (3) rebase-pip-pingpong-original (mpich-pingpong-original-bdw) failed
"""
[mpiexec@dn004] control_cb (pm/pmiserv/pmiserv_cb.c:207): assert (!closed) failed
[mpiexec@dn004] HYDT_dmxu_poll_wait_for_event (tools/demux/demux_poll.c:77): callback returned error status
[mpiexec@dn004] HYD_pmci_wait_for_completion (pm/pmiserv/pmiserv_pmci.c:195): error waiting for event
[mpiexec@dn004] main (ui/mpich/mpiexec.c:336): process manager error waiting for completion
"""

# The (1) pip-coll-double-copy can run correctly on the localhost, but it doesn't contains stealing code
# Run on another node will failed (it can't run on cross-node environment)
mpirun -n dn005 -n 64 miniGhost.x --npx 4 --npy 4 --npz 4 --num_vars 7 --nx 64 --ny 64 --nz 64 --stencil 23 --num_tsteps 6 --report_perf 1
"""
[mpiexec@dn004] control_cb (pm/pmiserv/pmiserv_cb.c:206): assert (!closed) failed
[mpiexec@dn004] HYDT_dmxu_poll_wait_for_event (tools/demux/demux_poll.c:76): callback returned error status
[mpiexec@dn004] HYD_pmci_wait_for_completion (pm/pmiserv/pmiserv_pmci.c:160): error waiting for event
[mpiexec@dn004] main (ui/mpich/mpiexec.c:326): process manager error waiting for completion
"""
