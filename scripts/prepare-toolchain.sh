#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLCHAINS_DIR="${ROOT_DIR}/toolchain"
OUT_DIR="${TOOLCHAINS_DIR}/current"

echo "==> RustForge — Prepare WASM toolchain"

mkdir -p "${OUT_DIR}"

RUST_WASM_BASE="${RUST_WASM_BASE:-https://rustwasm0.pages.dev}"
RUST_VERSION="${RUST_VERSION:-v3.0.0}"

echo "==> Intentando descargar toolchain WASM (${RUST_VERSION})…"

download() {
  local url="$1"
  local dest="$2"
  if command -v curl >/dev/null; then
    curl -fL --retry 3 -o "${dest}" "${url}" && return 0
  fi
  return 1
}

if download "${RUST_WASM_BASE}/${RUST_VERSION}/rustc.wasm" "${OUT_DIR}/rustc.wasm"; then
  echo "    rustc.wasm OK"
else
  echo "    AVISO: no se pudo descargar rustc.wasm (se usará placeholder)"
  echo "placeholder" > "${OUT_DIR}/rustc.wasm"
fi

if download "${RUST_WASM_BASE}/${RUST_VERSION}/cargo.wasm" "${OUT_DIR}/cargo.wasm"; then
  echo "    cargo.wasm OK"
else
  echo "    AVISO: no se pudo descargar cargo.wasm (se usará placeholder)"
  echo "placeholder" > "${OUT_DIR}/cargo.wasm"
fi

mkdir -p "${OUT_DIR}/sysroot"
echo "WASM sysroot placeholder" > "${OUT_DIR}/sysroot/README"

echo "==> Toolchain preparado en ${OUT_DIR}"
ls -la "${OUT_DIR}"
