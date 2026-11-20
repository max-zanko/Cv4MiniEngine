#!/usr/bin/env bash
set -euo pipefail
cmake -S . -B out/docker-build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PWD/out/docker-install" \
    -DPython2_ROOT_DIR=/opt/deps \
    -DPYBIND11_INC_DIR=/opt/src/pybind11/include \
    -DS3TC_DIR=/opt/src/s3tc-dxt-decompression \
    -DENABLE_NFD=OFF \
    "$@"
cmake --build out/docker-build --parallel "${BUILD_JOBS:-4}"
cmake --install out/docker-build
