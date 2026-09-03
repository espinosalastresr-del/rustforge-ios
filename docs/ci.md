# CI / GitHub Actions

## Workflows

### 1. `build-ide.yml` — Construir RustForge

1. **build-wamr** — Compila WAMR para iOS.
2. **prepare-toolchain** — Prepara rustc.wasm / cargo.wasm.
3. **build-app** — XcodeGen + xcodebuild.

### 2. `build.yml` — Build de proyectos de usuario

Inputs: `project_name`, `artifact_url`.

## Build local

```bash
./scripts/build-wamr.sh
./scripts/prepare-toolchain.sh
brew install xcodegen
xcodegen generate
xcodebuild -scheme RustForge -destination 'generic/platform=iOS' build
```
