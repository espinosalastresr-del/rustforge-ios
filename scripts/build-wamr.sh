#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build/wamr"
OUTPUT_DIR="${ROOT_DIR}/runtime/wamr/lib"

WAMR_VERSION="${WAMR_VERSION:-WAMR-2.1.0}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-17.0}"

echo "==> RustForge — Build WAMR for iOS"
echo "    Version: ${WAMR_VERSION}"
echo "    Deployment target: ${IOS_DEPLOYMENT_TARGET}"

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

if [ ! -d "${BUILD_DIR}/wasm-micro-runtime" ]; then
  echo "==> Cloning WAMR…"
  git clone --depth 1 --branch "${WAMR_VERSION}" \
    https://github.com/bytecodealliance/wasm-micro-runtime.git \
    "${BUILD_DIR}/wasm-micro-runtime"
fi

cd "${BUILD_DIR}/wasm-micro-runtime"

echo "==> Configuring CMake for iOS (arm64)…"
mkdir -p build-ios
cd build-ios

cmake .. \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DWAMR_BUILD_PLATFORM=darwin \
  -DWAMR_BUILD_TARGET=AARCH64 \
  -DWAMR_BUILD_INTERP=1 \
  -DWAMR_BUILD_AOT=0 \
  -DWAMR_BUILD_JIT=0 \
  -DWAMR_BUILD_LIBC_WASI=1 \
  -DWAMR_BUILD_LIBC_BUILTIN=1 \
  -DWAMR_BUILD_LIB_PTHREAD=0 \
  -DWAMR_BUILD_SIMD=0 \
  -DWAMR_BUILD_MULTI_MODULE=0 \
  -DWAMR_BUILD_MINI_LOADER=0 \
  -DWAMR_DISABLE_HW_BOUND_CHECK=1 \
  -DWAMR_BUILD_DEBUG_INTERP=0

echo "==> Building…"
cmake --build . --config Release -- -j"$(sysctl -n hw.ncpu)"

echo "==> Copying artifacts…"
find . -name "*.a" -exec cp {} "${OUTPUT_DIR}/" \;

echo "==> Done. Libraries in ${OUTPUT_DIR}"
ls -la "${OUTPUT_DIR}"
