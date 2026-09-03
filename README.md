# RustForge iOS

IDE de Rust para iPhone y iPad.

Desarrolla aplicaciones híbridas **SwiftUI + Rust** desde el dispositivo, con compilación on-device (WASM + WAMR + JIT) y linking final automatizado vía GitHub Actions.

## Características

- Editor de código + árbol de archivos
- rust-analyzer (bridge preparado)
- Compilación Rust on-device (WAMR)
- UI Builder (Drag & Drop → SwiftUI)
- Proyectos híbridos con FFI listo
- Cache de Cargo + modo offline
- Build remoto automatizado (GitHub Actions)
- Instalación en LiveContainer

## Requisitos de uso

- iOS 17.4+
- LiveContainer + StikDebug (JIT)
- Token de GitHub (para builds remotos de tus apps)

## Build del IDE con GitHub Actions

1. Sube el código a un repositorio GitHub.
2. El workflow **Build RustForge IDE** se ejecuta en push a `main`/`develop` o manualmente.
3. Jobs:
   - `build-wamr` — compila WAMR para iOS
   - `prepare-toolchain` — prepara rustc.wasm / cargo.wasm
   - `build-app` — XcodeGen + xcodebuild
4. Descarga el artifact `rustforge-ios-build`.

### Build local (Mac + Xcode)

```bash
brew install xcodegen
./scripts/build-wamr.sh          # opcional
./scripts/prepare-toolchain.sh   # opcional
xcodegen generate
xcodebuild \
  -project RustForge.xcodeproj \
  -scheme RustForge \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Estructura

```text
rustforge-ios/
├── app/RustForgeApp/     # UI SwiftUI del IDE
├── runtime/              # WAMR bridge, WASI, VFS
├── cargo/                # Cache de crates
├── analyzer/             # Bridge rust-analyzer
├── scripts/
├── tests/
├── docs/
├── project.yml           # XcodeGen
└── .github/workflows/
    ├── build-ide.yml     # CI del IDE
    └── build.yml         # CI de proyectos de usuario
```

## Estado (0.1.0-dev)

UI, editor, proyectos, UI Builder, runtime (simulación), BuildService, GitHub client, CI del IDE, plantillas híbridas FFI, SDK manager, Git básico.

Pendiente de entorno Mac/CI real: librería WAMR nativa, toolchain WASM real, rust-analyzer linkado, subida real de artefactos de usuario.
