#!/usr/bin/env bash
# Build everything in this repository that builds, on the platform it targets: 32-bit x86 Linux.
#
#   ci/build.sh [source-dir]      (default: the repository this script is in)
#
# Meant for a throwaway debian/eol:jessie container on linux/386 (Debian 8, gcc 4.9), which is
# how .github/workflows/build.yml runs it; it installs its own build dependencies there. It builds
# a copy, so the source tree is left untouched.
#
#   SFSlite              ./configure && make && make install
#   libbyz (BFT)         then bft-simple
#   libbyz (BASE)        then simple; BASE is switched on in State_defs.h, as the README says
#
# Not built: bfs and difs. Both mount NFSv2 through the kernel's legacy nfs_mount_data interface,
# and their nfs.h collides with <linux/nfs.h>; building them needs a port, not a build fix.
set -euo pipefail

SRC="$(cd "${1:-$(dirname "$0")/..}" && pwd)"
BUILD=/tmp/libbft-build
SFS_PREFIX=/opt/sfslite

if command -v apt-get >/dev/null && [ "$(id -u)" = 0 ]; then
  apt-get -o Acquire::Check-Valid-Until=false update
  apt-get install -y --force-yes --no-install-recommends g++ make libgmp-dev bison flex file
fi

rm -rf "${BUILD}"
cp -a "${SRC}" "${BUILD}"
cd "${BUILD}"

echo "::group::SFSlite"
(cd sfslite-1.2 && ./configure --prefix="${SFS_PREFIX}" && make -j"$(nproc)" && make install)
echo "::endgroup::"

# The Makefiles find SFSlite and GMP through these two links, as the README sets them up.
ln -sfn "${SFS_PREFIX}" sfs
ln -sfn /usr/lib gmp

echo "::group::libbyz (BFT) and bft-simple"
make -C libbyz
make -C bft-simple
echo "::endgroup::"

echo "::group::libbyz (BASE) and simple"
sed -i 's|^//#define BASE|#define BASE|' libbyz/State_defs.h
grep -q '^#define BASE' libbyz/State_defs.h || { echo "State_defs.h has no '//#define BASE' to switch on" >&2; exit 1; }
make -C libbyz clobber
make -C libbyz
make -C simple
echo "::endgroup::"

file bft-simple/simple-server bft-simple/simple-client simple/server simple/client
