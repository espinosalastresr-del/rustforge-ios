# Arquitectura de RustForge iOS

## Visión general

RustForge es un IDE móvil que permite desarrollar aplicaciones iOS nativas usando:

- **Rust** para la lógica de negocio y partes de alto rendimiento.
- **SwiftUI** para la interfaz de usuario (generada también mediante un diseñador visual).
- **WebAssembly + WAMR** para ejecutar rustc y Cargo on-device.
- **GitHub Actions** para el linking final y generación del `.ipa`.

## Componentes principales

### 1. App (SwiftUI)
- `RustForgeApp` — punto de entrada.
- `AppState` — estado global observable.
- Vistas: Projects, Editor, UI Builder, Terminal, Settings.
- `ProjectFileManager` — gestión de proyectos.

### 2. Runtime (WAMR)
- `WAMRRuntime` — puente WebAssembly.
- `VirtualFileSystem` — filesystem WASI.
- JIT mediante LiveContainer + StikDebug.

### 3. Toolchain
- `rustc.wasm`, `cargo.wasm`, sysroot.

### 4. UI Builder
- Drag & drop → código SwiftUI.

### 5. Integración CI
- Empaqueta sources + staticlib → GitHub Actions → `.ipa` → LiveContainer.

## Decisiones clave

| Decisión | Motivo |
|----------|--------|
| WAMR + JIT | Mejor rendimiento |
| Linking en GitHub Actions | Evitar linker on-device |
| SDK importado por usuario | Restricciones Apple |
| SwiftUI generado | UI nativa |
| LiveContainer | Ejecución sin firma compleja |
